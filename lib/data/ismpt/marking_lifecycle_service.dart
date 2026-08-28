import 'package:drift/drift.dart';
import 'package:telepos/core/constants/enums/marking_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/database/daos/marking_code_dao.dart';
import 'package:telepos/domain/ismpt/ismpt_models.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';

MarkingStatus markingStatusFromCis(MarkCisStatus cis) {
  switch (cis) {
    case MarkCisStatus.emitted:
    case MarkCisStatus.applied:
      return MarkingStatus.received;
    case MarkCisStatus.inCirculation:
      return MarkingStatus.inStock;
    case MarkCisStatus.retired:
      return MarkingStatus.retired;
    case MarkCisStatus.aggregated:
    case MarkCisStatus.reserved:
      return MarkingStatus.received;
    case MarkCisStatus.blocked:
      return MarkingStatus.blocked;
    case MarkCisStatus.unknown:
      return MarkingStatus.received;
  }
}

class LifecycleResult {
  const LifecycleResult({
    required this.localOk,
    required this.affected,
    required this.remote,
  });

  final bool localOk;

  final int affected;

  final IsMptResult remote;

  bool get ok => localOk;

  bool get remotePending =>
      remote.queued ||
      remote.errorCode == IsMptErrorCode.unsupported ||
      remote.errorCode == IsMptErrorCode.notConfigured;
}

class MarkingLifecycleService {
  MarkingLifecycleService({
    required AppDatabase db,
    required IsMptService ismpt,
  }) : _dao = db.markingCodeDao,
       _ismpt = ismpt;

  final MarkingCodeDao _dao;
  final IsMptService _ismpt;

  int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Future<LifecycleResult> acceptOnReceipt({
    required int ucode,
    required int supplyId,
    required List<String> codes,
    String? productGroup,
    String idempotencyKey = '',
    bool submitRemote = true,
  }) async {
    var affected = 0;
    for (final raw in codes) {
      final code = raw.trim();
      if (code.isEmpty) continue;
      final parsed = parseDataMatrix(code);
      final existing = await _dao.findByCode(code);
      final companion = MarkingCodesCompanion(
        ucode: Value(ucode),
        code: Value(code),
        gtin: Value(parsed.gtin),
        serial: Value(parsed.serial),
        batch: Value(parsed.batch),
        expiry: Value(parsed.expiry),
        status: Value(MarkingStatus.inStock.index),
        aggregationLevel: const Value(0),
        supplyId: Value(supplyId),
        updatedAt: Value(_now),
      );
      if (existing == null) {
        await _dao.insertCode(companion.copyWith(createdAt: Value(_now)));
      } else {
        await _dao.updateCode(existing.id, companion);
      }
      affected++;
    }

    IsMptResult remote = IsMptResult.notConfigured();
    if (submitRemote && codes.isNotEmpty) {
      remote = await _safeSubmit(
        IsMptDocRequest(
          idempotencyKey: idempotencyKey.isEmpty
              ? 'accept-$supplyId-$ucode'
              : idempotencyKey,
          type: IsMptDocType.acceptance,
          codes: codes,
          productGroup: productGroup,
          localRef: supplyId,
          occurredAt: DateTime.now(),
        ),
      );
    }
    return LifecycleResult(localOk: true, affected: affected, remote: remote);
  }

  Future<IsMptVerifyResult> verify(
    List<String> codes, {
    String? productGroup,
  }) async {
    final result = await _ismpt.verifyCodes(codes, productGroup: productGroup);
    if (result.success) {
      for (final v in result.verifications) {
        final row = await _dao.findByCode(v.code);
        if (row != null) {
          await _dao.updateStatus(row.id, markingStatusFromCis(v.status).index);
        }
      }
    }
    return result;
  }

  Future<LifecycleResult> recordWithdrawal({
    required List<String> codes,
    int? saleId,
    bool viaOfd = true,
    String? productGroup,
    String idempotencyKey = '',
  }) async {
    var affected = 0;
    for (final raw in codes) {
      final code = raw.trim();
      if (code.isEmpty) continue;
      final existing = await _dao.findByCode(code);
      if (existing == null) {
        final parsed = parseDataMatrix(code);
        await _dao.insertCode(
          MarkingCodesCompanion(
            ucode: const Value(0),
            code: Value(code),
            gtin: Value(parsed.gtin),
            serial: Value(parsed.serial),
            status: Value(MarkingStatus.retired.index),
            aggregationLevel: const Value(0),
            saleId: Value(saleId),
            createdAt: Value(_now),
            updatedAt: Value(_now),
          ),
        );
      } else {
        await _dao.updateCode(
          existing.id,
          MarkingCodesCompanion(
            status: Value(MarkingStatus.retired.index),
            saleId: Value(saleId),
            updatedAt: Value(_now),
          ),
        );
      }
      affected++;
    }

    IsMptResult remote = IsMptResult.ok();
    if (!viaOfd && codes.isNotEmpty) {
      remote = await _safeSubmit(
        IsMptDocRequest(
          idempotencyKey: idempotencyKey.isEmpty
              ? 'withdraw-${saleId ?? 0}-${codes.first}'
              : idempotencyKey,
          type: IsMptDocType.withdrawal,
          codes: codes,
          productGroup: productGroup,
          localRef: saleId,
          occurredAt: DateTime.now(),
        ),
      );
    }
    return LifecycleResult(localOk: true, affected: affected, remote: remote);
  }

  Future<LifecycleResult> aggregate({
    required String parentCode,
    required List<String> childCodes,
    int parentLevel = 1,
    int? ucode,
    String? productGroup,
    String idempotencyKey = '',
  }) async {
    var parent = await _dao.findByCode(parentCode);
    if (parent == null) {
      final id = await _dao.insertCode(
        MarkingCodesCompanion(
          ucode: Value(ucode ?? 0),
          code: Value(parentCode),
          status: Value(MarkingStatus.inStock.index),
          aggregationLevel: Value(parentLevel),
          createdAt: Value(_now),
          updatedAt: Value(_now),
        ),
      );
      parent = await (_daoFindById(id));
    }
    final parentId = parent!.id;

    var affected = 0;
    for (final raw in childCodes) {
      final code = raw.trim();
      if (code.isEmpty) continue;
      final child = await _dao.findByCode(code);
      if (child != null) {
        await _dao.updateCode(
          child.id,
          MarkingCodesCompanion(
            parentCodeId: Value(parentId),
            aggregationLevel: const Value(0),
            updatedAt: Value(_now),
          ),
        );
        affected++;
      }
    }

    final remote = await _safeSubmit(
      IsMptDocRequest(
        idempotencyKey: idempotencyKey.isEmpty
            ? 'aggr-$parentCode'
            : idempotencyKey,
        type: IsMptDocType.aggregation,
        codes: childCodes,
        parentCode: parentCode,
        productGroup: productGroup,
        occurredAt: DateTime.now(),
      ),
    );
    return LifecycleResult(localOk: true, affected: affected, remote: remote);
  }

  Future<LifecycleResult> disaggregate({
    required String parentCode,
    String? productGroup,
    String idempotencyKey = '',
  }) async {
    final parent = await _dao.findByCode(parentCode);
    if (parent == null) {
      return LifecycleResult(
        localOk: false,
        affected: 0,
        remote: IsMptResult.ok(),
      );
    }
    final children = await _dao.findChildren(parent.id);
    for (final c in children) {
      await _dao.updateCode(
        c.id,
        MarkingCodesCompanion(
          parentCodeId: const Value(null),
          updatedAt: Value(_now),
        ),
      );
    }
    final remote = await _safeSubmit(
      IsMptDocRequest(
        idempotencyKey: idempotencyKey.isEmpty
            ? 'disaggr-$parentCode'
            : idempotencyKey,
        type: IsMptDocType.disaggregation,
        codes: children.map((c) => c.code).toList(),
        parentCode: parentCode,
        productGroup: productGroup,
        occurredAt: DateTime.now(),
      ),
    );
    return LifecycleResult(
      localOk: true,
      affected: children.length,
      remote: remote,
    );
  }

  Future<LifecycleResult> transfer({
    required List<String> codes,
    required String counterpartyBin,
    String? productGroup,
    String idempotencyKey = '',
  }) async {
    final remote = await _safeSubmit(
      IsMptDocRequest(
        idempotencyKey: idempotencyKey.isEmpty
            ? 'transfer-$counterpartyBin'
            : idempotencyKey,
        type: IsMptDocType.transfer,
        codes: codes,
        counterpartyBin: counterpartyBin,
        productGroup: productGroup,
        occurredAt: DateTime.now(),
      ),
    );
    return LifecycleResult(
      localOk: true,
      affected: codes.length,
      remote: remote,
    );
  }

  Future<LifecycleResult> remark({
    required String oldCode,
    required String newCode,
    int? ucode,
    String? productGroup,
    String idempotencyKey = '',
  }) async {
    final old = await _dao.findByCode(oldCode);
    final resolvedUcode = ucode ?? old?.ucode ?? 0;
    if (old != null) {
      await _dao.updateStatus(old.id, MarkingStatus.retired.index);
    }
    final parsed = parseDataMatrix(newCode);
    final existingNew = await _dao.findByCode(newCode);
    final companion = MarkingCodesCompanion(
      ucode: Value(resolvedUcode),
      code: Value(newCode),
      gtin: Value(parsed.gtin),
      serial: Value(parsed.serial),
      status: Value(MarkingStatus.inStock.index),
      aggregationLevel: const Value(0),
      updatedAt: Value(_now),
    );
    if (existingNew == null) {
      await _dao.insertCode(companion.copyWith(createdAt: Value(_now)));
    } else {
      await _dao.updateCode(existingNew.id, companion);
    }

    final remote = await _safeSubmit(
      IsMptDocRequest(
        idempotencyKey: idempotencyKey.isEmpty
            ? 'remark-$oldCode'
            : idempotencyKey,
        type: IsMptDocType.remarking,
        codes: [oldCode, newCode],
        productGroup: productGroup,
        occurredAt: DateTime.now(),
      ),
    );
    return LifecycleResult(localOk: true, affected: 1, remote: remote);
  }

  Future<MarkingCode?> _daoFindById(int id) => _dao.findById(id);

  Future<IsMptResult> _safeSubmit(IsMptDocRequest req) async {
    try {
      return await _ismpt.submitDocument(req);
    } catch (e) {
      return IsMptResult.failure('$e', code: IsMptErrorCode.network);
    }
  }

  static ParsedMark parseDataMatrix(String code) {
    final gs = String.fromCharCode(0x1d);
    String? gtin;
    String? serial;
    String? batch;
    String? expiry;
    String? checksum;

    if (code.contains('(')) {
      final re = RegExp(r'\((\d{2,4})\)([^()]*)');
      for (final m in re.allMatches(code)) {
        final ai = m.group(1)!;
        final val = m.group(2)!;
        switch (ai) {
          case '01':
            gtin = val.trim();
          case '21':
            serial = val.trim();
          case '10':
            batch = val.trim();
          case '17':
            expiry = val.trim();
          case '93':
            checksum = val.trim();
        }
      }
      return ParsedMark(
        gtin: gtin,
        serial: serial,
        batch: batch,
        expiry: expiry,
        checksum: checksum,
      );
    }

    var s = code;
    int i = 0;
    while (i < s.length) {
      if (i + 2 > s.length) break;
      final ai = s.substring(i, i + 2);
      i += 2;
      switch (ai) {
        case '01':
          if (i + 14 <= s.length) {
            gtin = s.substring(i, i + 14);
            i += 14;
          } else {
            i = s.length;
          }
        case '17':
          if (i + 6 <= s.length) {
            expiry = s.substring(i, i + 6);
            i += 6;
          } else {
            i = s.length;
          }
        case '21':
          final end = _variableEnd(s, i, gs);
          serial = s.substring(i, end);
          i = _skipSep(s, end, gs);
        case '10':
          final end = _variableEnd(s, i, gs);
          batch = s.substring(i, end);
          i = _skipSep(s, end, gs);
        case '93':
          final end = _variableEnd(s, i, gs);
          checksum = s.substring(i, end);
          i = _skipSep(s, end, gs);
        default:
          i = s.length;
      }
    }
    return ParsedMark(
      gtin: gtin,
      serial: serial,
      batch: batch,
      expiry: expiry,
      checksum: checksum,
    );
  }

  static int _variableEnd(String s, int start, String gs) {
    final sep = s.indexOf(gs, start);
    final cap = (start + 20).clamp(0, s.length);
    if (sep >= 0 && sep <= cap) return sep;
    return cap;
  }

  static int _skipSep(String s, int end, String gs) {
    if (end < s.length && s[end] == gs) return end + 1;
    return end;
  }
}

class ParsedMark {
  const ParsedMark({
    this.gtin,
    this.serial,
    this.batch,
    this.expiry,
    this.checksum,
  });

  final String? gtin;
  final String? serial;
  final String? batch;
  final String? expiry;
  final String? checksum;
}
