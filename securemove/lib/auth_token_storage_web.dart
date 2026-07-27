import 'dart:html' as html;

class AuthTokenStorage {
  const AuthTokenStorage();

  Future<void> write({required String key, required String value}) async {
    html.window.localStorage[key] = value;
  }

  Future<String?> read({required String key}) async {
    return html.window.localStorage[key];
  }

  Future<void> delete({required String key}) async {
    html.window.localStorage.remove(key);
  }
}
