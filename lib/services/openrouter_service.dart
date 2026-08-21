import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'supabase_service.dart';

/// A single chat message in OpenAI-compatible format.
class AiMessage {
  const AiMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
  });

  final String role; // system | user | assistant | tool
  final String? content;
  final List<AiToolCall>? toolCalls;
  final String? toolCallId;

  Map<String, dynamic> toJson() => {
        'role': role,
        if (content != null) 'content': content,
        if (toolCalls != null && toolCalls!.isNotEmpty)
          'tool_calls': [for (final t in toolCalls!) t.toJson()],
        if (toolCallId != null) 'tool_call_id': toolCallId,
      };
}

/// An assistant request to invoke a tool.
class AiToolCall {
  const AiToolCall({required this.id, required this.name, required this.args});

  final String id;
  final String name;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': jsonEncode(args),
        },
      };

  factory AiToolCall.fromJson(Map<String, dynamic> json) => AiToolCall(
        id: json['id'] as String? ?? '',
        name: (json['function']?['name'] as String?) ?? '',
        args: _parseArgs(json['function']?['arguments']),
      );

  static Map<String, dynamic> _parseArgs(Object? raw) {
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map<String, dynamic> ? decoded : {};
      } catch (_) {
        return {};
      }
    }
    if (raw is Map<String, dynamic>) return raw;
    return {};
  }
}

/// A completed (non-streaming) model turn.
class AiCompletion {
  const AiCompletion({this.text, this.toolCalls, this.finishReason});

  final String? text;
  final List<AiToolCall>? toolCalls;
  final String? finishReason;

  bool get wantsToolCall => toolCalls != null && toolCalls!.isNotEmpty;
}

/// Streaming events for the Qubi chat view.
sealed class AiStreamEvent {
  const AiStreamEvent();
}

class AiStreamDelta extends AiStreamEvent {
  const AiStreamDelta(this.text);
  final String text;
}

class AiStreamToolCall extends AiStreamEvent {
  const AiStreamToolCall(this.toolCall);
  final AiToolCall toolCall;
}

class AiStreamDone extends AiStreamEvent {
  const AiStreamDone();
}

/// Tool schema exposed to the model — lets Qubi propose a habit plan that the
/// user approves and the app bulk-inserts.
const Map<String, Object> kCreateRoutinePlanTool = {
  'type': 'function',
  'function': {
    'name': 'create_routine_plan',
    'description':
        'Propose a daily routine by creating or updating the user’s habit plan. '
        'Returns a list of habits with title, category, days-per-week and time of day.',
    'parameters': {
      'type': 'object',
      'properties': {
        'habits': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'description': 'Short habit name'},
              'category': {
                'type': 'string',
                'enum': ['Fitness', 'Learning', 'Wellness', 'Chores', 'Creative'],
              },
              'frequency_days': {
                'type': 'array',
                'items': {'type': 'integer', 'minimum': 1, 'maximum': 7},
                'description': '0-indexed weekdays (0 = Monday … 6 = Sunday)',
              },
              'time_of_day': {'type': 'string', 'example': '8:00 AM'},
            },
            'required': ['title', 'time_of_day'],
          },
        },
      },
      'required': ['habits'],
    },
  },
};

/// OpenRouter-backed AI engine: chat completions, SSE streaming with tool-call
/// interception, and multimodal photo verification.
///
/// When no real API key is present the service degrades to a local simulator so
/// the UI remains fully testable offline.
class OpenRouterService {
  OpenRouterService._();

  static final OpenRouterService instance = OpenRouterService._();

  static const String endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _appUrl = 'https://questify.app';
  static const String _appTitle = 'Questify';

  bool get isConfigured => AppConfig.aiConfigured;
  String get _model => AppConfig.openRouterModel;
  String get _visionModel => AppConfig.openRouterVisionModel;

  /// Curated free, fast models to fall back to when the primary model is
  /// rate-limited (429) or the free tier is momentarily exhausted (402).
  static const List<String> _fallbackChatModels = [
    'google/gemma-4-26b-a4b-it:free',
    'google/gemma-4-31b-it:free',
  ];

  static const List<String> _fallbackVisionModels = [
    'google/gemma-4-31b-it:free',
    'nvidia/nemotron-nano-12b-v2-vl:free',
  ];

  /// Primary + fallbacks, deduped while preserving order.
  List<String> get _chatModels => _dedupe([_model, ..._fallbackChatModels]);
  List<String> get _visionModels => _dedupe([_visionModel, ..._fallbackVisionModels]);

  static List<String> _dedupe(List<String> models) {
    final seen = <String>{};
    return [for (final m in models) if (seen.add(m)) m];
  }

  Map<String, String> _headers() => {
        'Authorization': 'Bearer ${AppConfig.openRouterKey}',
        'Content-Type': 'application/json',
        'HTTP-Referer': _appUrl,
        'X-Title': _appTitle,
      };

  // ── Non-streaming completion ──────────────────────────────────────────────

  Future<AiCompletion> complete({
    required List<AiMessage> messages,
    bool tools = true,
    Map<String, Object>? toolChoice,
  }) async {
    if (!isConfigured) return _simulate(messages);

    AiHttpException? lastError;
    for (final model in _chatModels) {
      try {
        return await _completeWithModel(
          model,
          messages,
          tools: tools,
          toolChoice: toolChoice,
        );
      } on AiHttpException catch (e) {
        if (!e.retryable) rethrow;
        lastError = e;
      } on TimeoutException {
        lastError = const AiHttpException(504, 'request timed out');
      }
      await _cooldown();
    }
    throw lastError ??
        const AiHttpException(502, 'All AI models are unavailable.');
  }

  Future<AiCompletion> _completeWithModel(
    String model,
    List<AiMessage> messages, {
    required bool tools,
    Map<String, Object>? toolChoice,
  }) async {
    final res = await http
        .post(
          Uri.parse(endpoint),
          headers: _headers(),
          body: jsonEncode({
            'model': model,
            'messages': [for (final m in messages) m.toJson()],
            if (tools) 'tools': [kCreateRoutinePlanTool],
            if (tools && toolChoice != null) 'tool_choice': toolChoice,
            'temperature': 0.7,
            'max_tokens': 900,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode != 200) {
      throw AiHttpException(res.statusCode, res.body);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choice = ((data['choices'] as List?)?.first) as Map<String, dynamic>?;
    final message = choice?['message'] as Map<String, dynamic>?;
    return AiCompletion(
      text: message?['content'] as String?,
      toolCalls: [
        for (final t in (message?['tool_calls'] as List? ?? []))
          AiToolCall.fromJson(t as Map<String, dynamic>),
      ],
      finishReason: choice?['finish_reason'] as String?,
    );
  }

  /// SSE streaming with tool-call interception. Emits [AiStreamDelta] for
  /// text tokens and [AiStreamToolCall] once a tool invocation completes.
  /// Retries the stream on the next free model when the current one is
  /// rate-limited (as long as no text was already streamed).
  Stream<AiStreamEvent> streamChat({
    required List<AiMessage> messages,
  }) async* {
    if (!isConfigured) {
      final sim = _simulate(messages);
      for (final chunk in sim.text == null
          ? <String>[]
          : _chunk(sim.text!, 14)) {
        yield AiStreamDelta(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 24));
      }
      if (sim.toolCalls != null && sim.toolCalls!.isNotEmpty) {
        for (final t in sim.toolCalls!) {
          yield AiStreamToolCall(t);
        }
      }
      yield const AiStreamDone();
      return;
    }

    AiHttpException? lastError;
    for (final model in _chatModels) {
      var emitted = false;
      try {
        await for (final ev in _streamWithModel(model, messages)) {
          emitted = true;
          yield ev;
        }
        return;
      } on AiHttpException catch (e) {
        if (emitted || !e.retryable) rethrow;
        lastError = e;
      } on TimeoutException {
        if (emitted) rethrow;
        lastError = const AiHttpException(504, 'request timed out');
      }
      await _cooldown();
    }
    throw lastError ??
        const AiHttpException(502, 'All AI models are unavailable.');
  }

  Stream<AiStreamEvent> _streamWithModel(
    String model,
    List<AiMessage> messages,
  ) async* {
    final req = http.Request('POST', Uri.parse(endpoint))
      ..headers.addAll(_headers())
      ..body = jsonEncode({
        'model': model,
        'messages': [for (final m in messages) m.toJson()],
        'tools': [kCreateRoutinePlanTool],
        'stream': true,
        'temperature': 0.7,
        'max_tokens': 900,
      });

    final client = http.Client();
    http.StreamedResponse res;
    try {
      res = await client.send(req).timeout(const Duration(seconds: 45));
    } catch (_) {
      client.close();
      rethrow;
    }

    if (res.statusCode != 200) {
      client.close();
      throw AiHttpException(res.statusCode, await res.stream.bytesToString());
    }

    var buffer = '';
    final toolCalls = <_PartialToolCall>[];
    try {
      await for (final chunk in res.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (true) {
          final nl = buffer.indexOf('\n');
          if (nl < 0) break;
          final line = buffer.substring(0, nl).trim();
          buffer = buffer.substring(nl + 1);
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload == '[DONE]') {
            // Flush any partial tool call.
            for (final p in toolCalls) {
              yield AiStreamToolCall(p.build());
            }
            toolCalls.clear();
            yield const AiStreamDone();
            return;
          }
          if (payload.startsWith('{')) {
            try {
              final json = jsonDecode(payload) as Map<String, dynamic>;
              final err = json['error'];
              if (err != null) {
                final msg = (err is Map)
                    ? (err['message'] as String? ?? 'OpenRouter error')
                    : err.toString();
                throw AiHttpException(402, msg);
              }
              final delta = (json['choices'] as List?)
                  ?.first?['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield AiStreamDelta(content);
              }
              for (final t in (delta?['tool_calls'] as List? ?? [])) {
                final call = t as Map<String, dynamic>;
                final idx = (call['index'] as num?)?.toInt() ?? 0;
                while (toolCalls.length <= idx) {
                  toolCalls.add(_PartialToolCall());
                }
                final partial = toolCalls[idx];
                final fn = call['function'] as Map<String, dynamic>?;
                if (call['id'] is String) partial.id = call['id'] as String;
                if (fn?['name'] is String) partial.name = fn!['name'] as String;
                if (fn?['arguments'] is String) {
                  partial.argsBuffer += fn!['arguments'] as String;
                }
              }
            } catch (e) {
              if (e is AiHttpException) rethrow;
              // Skip malformed keep-alive / partial frames.
            }
          }
        }
      }
    } finally {
      client.close();
    }
    // End of stream without [DONE]: flush partial tool calls if any.
    for (final p in toolCalls) {
      yield AiStreamToolCall(p.build());
    }
    yield const AiStreamDone();
  }

  // ── Vision: photo proof verification ──────────────────────────────────────

  /// Asks the vision model whether the photo plausibly shows [expected]
  /// (e.g. "your book"). Returns a structured verdict. When the photo does not
  /// prove the claim the verdict's reason describes what the photo actually
  /// shows and states that it cannot be proved. Falls back to other free
  /// vision models when the primary one is rate-limited.
  Future<VisionVerdict> verifyPhoto({
    required Uint8List bytes,
    required String expected,
  }) async {
    if (!isConfigured || bytes.isEmpty) {
      // Demo fallback: deterministic accept so the flow is testable offline
      // (and for simulated captures on devices without a camera).
      return const VisionVerdict(
        verified: true,
        confidence: 0.96,
        reason: 'Demo mode — photo accepted.',
      );
    }

    AiHttpException? lastError;
    for (final model in _visionModels) {
      try {
        return await _verifyWithModel(model, bytes, expected);
      } on AiHttpException catch (e) {
        if (!e.retryable) rethrow;
        lastError = e;
      } on TimeoutException {
        lastError = const AiHttpException(504, 'request timed out');
      }
      await _cooldown();
    }
    throw lastError ??
        const AiHttpException(502, 'All AI models are unavailable.');
  }

  Future<VisionVerdict> _verifyWithModel(
    String model,
    Uint8List bytes,
    String expected,
  ) async {
    final res = await http
        .post(
          Uri.parse(endpoint),
          headers: _headers(),
          body: jsonEncode({
            'model': model,
            'temperature': 0.1,
            'max_tokens': 600,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text':
                        'You are a strict but fair habit-proof verifier for the Questify app. '
                        'The user claims this photo proves they completed: "$expected". '
                        'FIRST inspect the entire photo and determine exactly what object or scene it actually shows. '
                        'Then decide whether the photo plausibly proves the claimed habit. '
                        'Answer ONLY with a JSON object: '
                        '{"verified": true|false, "confidence": 0..1, "reason": "one sentence"}. '
                        'Set verified=true only when the claimed item is clearly present in the photo. '
                        'If verified=false, your reason MUST say what the photo actually shows and state '
                        'that it cannot be proved (example: "The photo shows a coffee cup, not your book — '
                        'this cannot be proved.").',
                  },
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': base64DataUri(bytes, 'image/jpeg'),
                    },
                  },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) {
      throw AiHttpException(res.statusCode, res.body);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final text = (data['choices'] as List?)?.first?['message']?['content'] as String?;
    return VisionVerdict.parse(text ?? '{}');
  }

  /// Small pause between model attempts so rate limits can cool down.
  static Future<void> _cooldown() =>
      Future<void>.delayed(const Duration(milliseconds: 400));

  // ── Demo simulator ────────────────────────────────────────────────────────

  AiCompletion _simulate(List<AiMessage> messages) {
    final last = messages.lastOrNull;
    final prompt = (last?.content ?? '').toLowerCase();
    final mentionsPlan = prompt.contains('routine') || prompt.contains('plan');
    if (mentionsPlan) {
      return AiCompletion(
        finishReason: 'tool_calls',
        toolCalls: [
          AiToolCall(
            id: 'sim_plan_1',
            name: 'create_routine_plan',
            args: {
              'habits': [
                {
                  'title': 'Morning Stretch',
                  'category': 'Wellness',
                  'frequency_days': [0, 1, 2, 3, 4, 5, 6],
                  'time_of_day': '7:00 AM',
                },
                {
                  'title': 'Read 20 min',
                  'category': 'Learning',
                  'frequency_days': [0, 1, 2, 3, 4, 5, 6],
                  'time_of_day': '9:00 PM',
                },
              ],
            },
          ),
        ],
      );
    }
    final reply = switch (prompt) {
      _ when prompt.contains('why') || prompt.contains('miss') =>
        'Your streak is safest when a quest has a backup slot. I found that '
            'Gym is your most-skipped quest — let’s move it to your high-energy '
            'window (6:30 PM) and add a 5-minute warmup trigger.',
      _ => 'On it! To keep your streak alive, snap a photo proof and I’ll '
          'verify it. Ask me to optimize your routine anytime.',
    };
    return AiCompletion(text: reply, finishReason: 'stop');
  }

  List<String> _chunk(String text, int size) => [
        for (var i = 0; i < text.length; i += size)
          text.substring(i, i + size > text.length ? text.length : i + size),
      ];
}

/// Accumulator for a tool call streamed across multiple SSE deltas.
class _PartialToolCall {
  String id = '';
  String name = '';
  String argsBuffer = '';

  AiToolCall build() {
    Map<String, dynamic> args = {};
    if (argsBuffer.isNotEmpty) {
      try {
        final decoded = jsonDecode(argsBuffer);
        if (decoded is Map<String, dynamic>) args = decoded;
      } catch (_) {}
    }
    return AiToolCall(id: id, name: name, args: args);
  }
}

/// Structured vision verdict.
class VisionVerdict {
  const VisionVerdict({
    required this.verified,
    required this.confidence,
    required this.reason,
  });

  final bool verified;
  final double confidence;
  final String reason;

  factory VisionVerdict.parse(String raw) {
    try {
      var cleaned = raw
          .replaceAll(RegExp(r'^```(?:json)?\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
      // Some models wrap the JSON in commentary — extract the first {…} object.
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start >= 0 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return VisionVerdict(
        verified: json['verified'] == true,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        reason: (json['reason'] as String?) ?? 'No reason given.',
      );
    } catch (_) {
      return const VisionVerdict(
        verified: false,
        confidence: 0,
        reason: 'The verifier could not parse a verdict.',
      );
    }
  }
}

class AiHttpException implements Exception {
  const AiHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  /// Whether a different free model can be tried for this failure.
  bool get retryable =>
      statusCode == 402 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504 ||
      statusCode == 408;

  /// Short, human-friendly message for chat bubbles / toasts.
  String get userMessage {
    if (statusCode == 402) {
      return 'Every free AI model Qubi tried is busy right now. Wait a few '
          'seconds and retry — or add a few dollars of credits at '
          'openrouter.ai to unlock the fast paid models.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'AI is configured but the key was rejected. Check OPENROUTER_API_KEY in .env.';
    }
    if (statusCode == 429) {
      return 'All the free AI models are rate-limited at the moment. Give it '
          'a few seconds, then try again.';
    }
    if (statusCode == 502) {
      return 'All AI models are unreachable right now — check your connection and try again.';
    }
    return 'I hit a snag talking to my brain (HTTP $statusCode). Please try again.';
  }

  @override
  String toString() => 'OpenRouter error $statusCode: ${body.length > 240 ? body.substring(0, 240) : body}';
}
