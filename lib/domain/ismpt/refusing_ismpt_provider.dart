import 'package:telepos/domain/ismpt/ismpt_models.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';

/// Служба ИС МПТ, которая **ничего не умеет и об этом говорит**.
///
/// Подставляется реестром, когда бэкенд маркировки не выбран
/// (`IsMptBackend.none`) либо выбран, но не зарегистрирован; существует ради
/// необнуляемого порта.
///
/// **Контракт: каждый член возвращает названный отказ.** В отличие от трёх
/// родственников, прежний `NoOpIsMptProvider` **не лгал ни одним членом** —
/// все четыре уже отвечали `notConfigured` либо `unsupported`. Переименование
/// здесь выравнивает имя с поведением, а не чинит поведение: класс, названный
/// `NoOp`, читается как «делает ничего и это нормально», и рядом с тремя
/// врущими тёзками он их прикрывал.
class RefusingIsMptProvider implements IsMptService {
  const RefusingIsMptProvider();

  @override
  String get id => 'ismpt_refusing';

  @override
  IsMptCapabilities get capabilities => IsMptCapabilities.none;

  @override
  Future<IsMptResult> authorize() async => IsMptResult.notConfigured();

  @override
  Future<IsMptVerifyResult> verifyCodes(
    List<String> codes, {
    String? productGroup,
  }) async => IsMptVerifyResult.unsupported();

  @override
  Future<IsMptResult> submitDocument(IsMptDocRequest req) async =>
      IsMptResult.notConfigured();

  @override
  Future<IsMptStatus> getStatus() async => IsMptStatus.notConfigured();
}
