// supabase/functions/send-verification/index.ts
// Edge Function that sends verification emails via Resend.
// Deploy with: supabase functions deploy send-verification
// Set secret: supabase secrets set RESEND_API_KEY=re_...

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/** SHA-256 hash -> hex string (Web Crypto API). */
async function sha256hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function jsonResp(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  // CORS preflight.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, email, code } = await req.json();

    // -- SUPABASE ADMIN CLIENT (service_role -- bypasses RLS) --
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // -- SEND --
    if (action === "send") {
      if (!email || !code) {
        return jsonResp({ error: "email and code are required" }, 400);
      }

      // Hash the plain code server-side.
      const code_hash = await sha256hex(code.trim());

      // Insert verification code.
      const { error: insertErr } = await supabase
        .from("verification_codes")
        .insert({
          email: email.toLowerCase(),
          code_hash,
          status: "pending",
        });
      if (insertErr) {
        console.error("insert error:", insertErr);
        return jsonResp({ error: "Failed to store verification code" }, 500);
      }

      // Send email via Resend.
      const resendRes = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "Questify <noreply@questify-app.com>",
          to: email,
          subject: "Your Questify Verification Code",
          html: `<div style="font-family:system-ui,-apple-system,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;text-align:center">
            <h2 style="font-size:24px;font-weight:800;margin-bottom:8px">Verify your email</h2>
            <p style="color:#64748b;font-size:14px;margin-bottom:24px">Enter this 6-digit code in the Questify app to complete your sign-up.</p>
            <div style="font-size:36px;font-weight:900;letter-spacing:12px;color:#6C5CE7;margin-bottom:24px">${code}</div>
            <p style="color:#94a3b8;font-size:12px">This code expires in 15 minutes. If you didn't create an account, ignore this email.</p>
          </div>`,
        }),
      });

      if (!resendRes.ok) {
        const errText = await resendRes.text();
        console.error("resend error:", errText);
        // Rollback: remove the stored code.
        await supabase
          .from("verification_codes")
          .delete()
          .eq("email", email.toLowerCase())
          .eq("status", "pending");
        return jsonResp(
          { error: "Failed to send verification email" },
          502,
        );
      }

      return jsonResp({ ok: true });
    }

    // -- VERIFY --
    if (action === "verify") {
      if (!email || !code) {
        return jsonResp({ error: "email and code are required" }, 400);
      }

      const tokenHash = await sha256hex(code.trim());

      const { data: codes } = await supabase
        .from("verification_codes")
        .select("*")
        .eq("email", email.toLowerCase())
        .eq("code_hash", tokenHash)
        .eq("status", "pending")
        .gt("expires_at", new Date().toISOString())
        .limit(1);

      if (!codes || codes.length === 0) {
        return jsonResp(
          { error: "Invalid or expired verification code" },
          401,
        );
      }

      // Mark as verified.
      await supabase
        .from("verification_codes")
        .update({ status: "verified" })
        .eq("id", codes[0].id);

      return jsonResp({ ok: true });
    }

    // -- CONFIRM-EMAIL --
    // After code verification, confirm the Supabase user's email via admin API.
    // Used for legacy unverified accounts or when Supabase email confirmation is ON.
    if (action === "confirm-email") {
      if (!email) {
        return jsonResp({ error: "email is required" }, 400);
      }

      // Find the user by email using paginated list (admin API).
      // Use large perPage to minimize round-trips.
      let user: { id: string; email_confirmed_at?: string } | null = null;
      let page = 1;
      const perPage = 1000;
      const maxPages = 10; // Safety cap: 10k users max

      while (!user && page <= maxPages) {
        const { data, error: listErr } =
          await supabase.auth.admin.listUsers({
            page,
            perPage,
          });

        if (listErr) {
          console.error("listUsers error:", listErr);
          return jsonResp({ error: "Failed to look up user" }, 500);
        }

        const found = data?.users?.find(
          (u) => u.email?.toLowerCase() === email.toLowerCase(),
        );

        if (found) {
          user = found;
        } else if (!data?.users || data.users.length < perPage) {
          // No more pages — user not found.
          break;
        } else {
          page++;
        }
      }

      if (!user) {
        return jsonResp({ error: "User not found" }, 404);
      }

      // Already confirmed — nothing to do.
      if (user.email_confirmed_at) {
        return jsonResp({ ok: true, message: "Email already confirmed" });
      }

      // Confirm the email via admin update.
      const { error: updateErr } = await supabase.auth.admin.updateUserById(
        user.id,
        { email_confirm: true },
      );

      if (updateErr) {
        console.error("confirm-email error:", updateErr);
        return jsonResp({ error: "Failed to confirm email" }, 500);
      }

      return jsonResp({ ok: true });
    }

    return jsonResp({ error: "Unknown action" }, 400);
  } catch (err) {
    console.error("edge function error:", err);
    return jsonResp({ error: "Internal server error" }, 500);
  }
});
