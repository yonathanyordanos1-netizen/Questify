import 'package:flutter_test/flutter_test.dart';
import 'package:questify/services/update_service.dart';

void main() {
  test('update is newer than local', () {
    const local = UpdateInfo(appName: 'q', version: '1.0.0', buildNumber: '1', packageName: 'q');
    const older = UpdateInfo(appName: 'q', version: '0.9.9', buildNumber: '9', packageName: 'q');
    const newer = UpdateInfo(appName: 'q', version: '1.1.0', buildNumber: '2', packageName: 'q');
    const same = UpdateInfo(appName: 'q', version: '1.0.0', buildNumber: '1', packageName: 'q');
    const newerBuild = UpdateInfo(appName: 'q', version: '1.0.0', buildNumber: '2', packageName: 'q');
    expect(local.isNewerThan('1.0.0', localBuildNumber: '1'), isFalse);
    expect(older.isNewerThan('1.0.0', localBuildNumber: '1'), isFalse);
    expect(newer.isNewerThan('1.0.0', localBuildNumber: '1'), isTrue);
    expect(same.isNewerThan('1.0.0', localBuildNumber: '1'), isFalse);
    expect(newerBuild.isNewerThan('1.0.0', localBuildNumber: '1'), isTrue);
  });
}
