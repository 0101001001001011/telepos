/// Какой терминал этот клиент.
///
/// Хранится **у клиента**, а не в базе кассы: касса знает, какие терминалы
/// существуют, а браузер или окно — кто из них он. Новый браузер без записи —
/// это новый терминал, и он проходит короткий мастер.
/// См. docs/system-architecture.md, раздел 4.
abstract interface class TerminalIdentity {
  Future<int?> currentId();

  Future<void> remember(int terminalId);

  /// Забывает запомненный id. Заведён для одного случая: касса, к которой
  /// подключена эта вкладка, восстановлена из резервной копии, терминалы
  /// пересозданы с новыми id, а localStorage браузера пережил восстановление
  /// и всё ещё называет старый — [LoginNotifier] (`login_controller.dart`)
  /// ловит это по [UnknownTerminalException] и зовёт [forget], чтобы
  /// следующая попытка снова прошла через [TerminalRepository.register]/
  /// [TerminalRepository.self], как в самый первый раз.
  Future<void> forget();
}
