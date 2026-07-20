import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/utils/remote_path_utils.dart';

void main() {
  group('RemotePath.join', () {
    test('joins unix segments', () {
      expect(RemotePath.join('/home/user', 'docs'), '/home/user/docs');
    });

    test('joins windows drive paths without dropping drive', () {
      expect(RemotePath.join('C:/', 'Users'), 'C:/Users');
      expect(RemotePath.join('C:/Users', 'lukas'), 'C:/Users/lukas');
    });

    test('strips duplicate slashes', () {
      expect(RemotePath.join('C:/Users/', '/lukas'), 'C:/Users/lukas');
    });
  });

  group('RemotePath.parent', () {
    test('parent of nested unix path', () {
      expect(RemotePath.parent('/a/b/c'), '/a/b');
    });

    test('parent of drive root is itself', () {
      expect(RemotePath.parent('C:/'), 'C:/');
    });

    test('parent under drive', () {
      expect(RemotePath.parent('C:/Users'), 'C:/');
    });
  });

  group('RemotePath.isRoot', () {
    test('unix and drive roots', () {
      expect(RemotePath.isRoot('/'), isTrue);
      expect(RemotePath.isRoot('C:/'), isTrue);
      expect(RemotePath.isRoot('C:/Users'), isFalse);
    });
  });
}
