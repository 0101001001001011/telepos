library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:get_it/get_it.dart';

import 'package:telepos/core/constants/enums/marking_status.dart';
import 'package:telepos/data/database/app_database.dart';
import 'package:telepos/data/ismpt/ismpt_offline_queueing_provider.dart';
import 'package:telepos/data/ismpt/marking_lifecycle_service.dart';
import 'package:telepos/domain/ismpt/ismpt_models.dart';
import 'package:telepos/domain/ismpt/ismpt_provider_registry.dart';
import 'package:telepos/domain/ismpt/ismpt_service.dart';
import 'package:telepos/domain/ismpt/refusing_ismpt_provider.dart';

import '../support/harness.dart';

const _gs = '';
const _code1 = '010460700123456721ABC123$_gs93Xy9z';
const _codeTobacco = '0104870249811936215abcd9$_gs93dGVz';

class _ControllableIsMpt implements IsMptService {
  bool online = true;
  final List<String> submitted = [];
  final List<String> verified = [];
  IsMptResult? nextSubmit;
  bool throwOnSubmit = false;
  final Map<String, MarkCisStatus> verifyStatuses = {};

  @override
  String get id => 'controllable';

  @override
  IsMptCapabilities get capabilities => const IsMptCapabilities(
    supportsVerify: true,
    supportsAcceptance: true,
    supportsWithdrawal: true,
    supportsAggregation: true,
    supportsTransfer: true,
    supportsRemarking: true,
  );

  @override
  Future<IsMptResult> authorize() async => IsMptResult.ok();

  @override
  Future<IsMptVerifyResult> verifyCodes(
    List<String> codes, {
    String? productGroup,
  }) async {
    verified.addAll(codes);
    return IsMptVerifyResult.ok([
      for (final c in codes)
        MarkVerification(
          code: c,
          status: verifyStatuses[c] ?? MarkCisStatus.inCirculation,
          valid:
              (verifyStatuses[c] ?? MarkCisStatus.inCirculation) ==
              MarkCisStatus.inCirculation,
        ),
    ]);
  }

  @override
  Future<IsMptResult> submitDocument(IsMptDocRequest req) async {
    submitted.add(req.idempotencyKey);
    if (throwOnSubmit) throw Exception('socket closed');
    if (nextSubmit != null) {
      final r = nextSubmit!;
      nextSubmit = null;
      return r;
    }
    return IsMptResult.ok(documentId: 'DOC-${req.idempotencyKey}');
  }

  @override
  Future<IsMptStatus> getStatus() async =>
      IsMptStatus(configured: true, online: online);
}

IsMptOfflineQueueingProvider _wrap(
  _ControllableIsMpt inner,
  IsMptQueueStore store,
) => IsMptOfflineQueueingProvider(
  inner: inner,
  store: store,
  isReachable: () async => inner.online,
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  group('Acceptance on goods receipt (приёмка)', () {
    test('receiving marked goods records each code with accepted (in_stock) '
        'status, linked to the supply, GTIN/serial parsed', () async {
      final svc = MarkingLifecycleService(
        db: db,
        ismpt: IsMptOfflineQueueingProvider(
          inner: const RefusingIsMptProvider(),
          store: InMemoryIsMptQueueStore(),
          isReachable: () async => false,
        ),
      );

      const ucode = 5001;
      const supplyId = 77;
      final res = await svc.acceptOnReceipt(
        ucode: ucode,
        supplyId: supplyId,
        codes: const [_code1, _codeTobacco],
      );

      expect(res.localOk, isTrue, reason: 'приёмка records locally');
      expect(res.affected, 2);
      expect(res.remotePending, isTrue);

      final rows = await db.markingCodeDao.findBySupplyId(supplyId);
      expect(rows.length, 2, reason: 'both codes linked to the supply');
      for (final r in rows) {
        expect(
          r.status,
          MarkingStatus.inStock.index,
          reason: 'accepted = in circulation / in_stock',
        );
        expect(r.ucode, ucode);
        expect(r.supplyId, supplyId);
        expect(r.aggregationLevel, 0);
      }
      final c1 = await db.markingCodeDao.findByCode(_code1);
      expect(c1, isNotNull);
      expect(c1!.gtin, '04607001234567');
      expect(c1.serial, 'ABC123');
    });

    test(
      're-accepting the same code updates (idempotent), no duplicate row',
      () async {
        final svc = MarkingLifecycleService(
          db: db,
          ismpt: const RefusingIsMptProvider(),
        );

        await svc.acceptOnReceipt(ucode: 1, supplyId: 1, codes: const [_code1]);
        await svc.acceptOnReceipt(ucode: 1, supplyId: 2, codes: const [_code1]);

        final all = await db.markingCodeDao.findByCode(_code1);
        expect(all, isNotNull);
        final supply1 = await db.markingCodeDao.findBySupplyId(1);
        final supply2 = await db.markingCodeDao.findBySupplyId(2);
        expect(supply1, isEmpty, reason: 're-accept moved it to supply 2');
        expect(supply2.length, 1);
      },
    );
  });

  group('Withdrawal on sale (выбытие)', () {
    test(
      'selling a marked good marks its codes выбыт (retired) and links them '
      'to the saleId; via OFD no duplicate ИС МПТ document is submitted',
      () async {
        final inner = _ControllableIsMpt()..online = true;
        final store = InMemoryIsMptQueueStore();
        final svc = MarkingLifecycleService(db: db, ismpt: _wrap(inner, store));

        await svc.acceptOnReceipt(
          ucode: 6001,
          supplyId: 9,
          codes: const [_code1],
          submitRemote: false,
        );
        var row = await db.markingCodeDao.findByCode(_code1);
        expect(row!.status, MarkingStatus.inStock.index);

        const saleId = 4242;
        final res = await svc.recordWithdrawal(
          codes: const [_code1],
          saleId: saleId,
          viaOfd: true,
        );

        expect(res.localOk, isTrue);
        expect(res.affected, 1);

        row = await db.markingCodeDao.findByCode(_code1);
        expect(
          row!.status,
          MarkingStatus.retired.index,
          reason: 'выбытие → retired',
        );
        expect(
          row.saleId,
          saleId,
          reason: 'code linked to the sale that выбыл it',
        );

        expect(
          inner.submitted,
          isEmpty,
          reason: 'OFD path is authoritative for выбытие',
        );
      },
    );

    test('manual выбытие (no OFD-scan path) submits a withdrawal document, '
        'queued offline — never blocks', () async {
      final inner = _ControllableIsMpt()..online = false;
      final store = InMemoryIsMptQueueStore();
      final svc = MarkingLifecycleService(db: db, ismpt: _wrap(inner, store));

      await svc.acceptOnReceipt(
        ucode: 1,
        supplyId: 1,
        codes: const [_code1],
        submitRemote: false,
      );

      final res = await svc.recordWithdrawal(
        codes: const [_code1],
        saleId: 7,
        viaOfd: false,
        idempotencyKey: 'W-1',
      );

      expect(res.localOk, isTrue);
      expect(res.remote.queued, isTrue);
      expect(await store.pendingCount(), 1);
      expect(inner.submitted, isEmpty);

      final row = await db.markingCodeDao.findByCode(_code1);
      expect(row!.status, MarkingStatus.retired.index);

      inner.online = true;
      final provider = _wrap(inner, store);
      final report = await IsMptOfflineQueueingProvider(
        inner: inner,
        store: store,
        isReachable: () async => true,
      ).replay();
      expect(report.submitted, 1);
      expect(inner.submitted, contains('W-1'));
      expect(await store.pendingCount(), 0);
      expect(provider.id, 'controllable');
    });

    test(
      'selling a code that was never accepted still records its выбытие',
      () async {
        final svc = MarkingLifecycleService(
          db: db,
          ismpt: const RefusingIsMptProvider(),
        );

        final res = await svc.recordWithdrawal(
          codes: const [_code1],
          saleId: 99,
          viaOfd: true,
        );
        expect(res.affected, 1);
        final row = await db.markingCodeDao.findByCode(_code1);
        expect(row, isNotNull);
        expect(row!.status, MarkingStatus.retired.index);
        expect(row.saleId, 99);
      },
    );
  });

  group('Status verification seam', () {
    test('verify persists the reported CIS status locally and reports in '
        'circulation', () async {
      final inner = _ControllableIsMpt()..online = true;
      final svc = MarkingLifecycleService(
        db: db,
        ismpt: _wrap(inner, InMemoryIsMptQueueStore()),
      );

      await svc.acceptOnReceipt(
        ucode: 1,
        supplyId: 1,
        codes: const [_code1],
        submitRemote: false,
      );
      inner.verifyStatuses[_code1] = MarkCisStatus.inCirculation;

      final res = await svc.verify([_code1]);
      expect(res.success, isTrue);
      expect(res.verifications.single.isInCirculation, isTrue);
      final row = await db.markingCodeDao.findByCode(_code1);
      expect(row!.status, MarkingStatus.inStock.index);
    });

    test('verify of a retired/blocked code maps to local status', () async {
      final inner = _ControllableIsMpt()..online = true;
      final svc = MarkingLifecycleService(
        db: db,
        ismpt: _wrap(inner, InMemoryIsMptQueueStore()),
      );
      await svc.acceptOnReceipt(
        ucode: 1,
        supplyId: 1,
        codes: const [_code1],
        submitRemote: false,
      );

      inner.verifyStatuses[_code1] = MarkCisStatus.blocked;
      await svc.verify([_code1]);
      final row = await db.markingCodeDao.findByCode(_code1);
      expect(row!.status, MarkingStatus.blocked.index);
    });

    test('verify is HONEST when account-gated: NoOp returns unsupported, NOT a '
        'fake valid status (offline-safe, never throws)', () async {
      final svc = MarkingLifecycleService(
        db: db,
        ismpt: const RefusingIsMptProvider(),
      );
      final res = await svc.verify([_code1]);
      expect(res.success, isFalse);
      expect(res.errorCode, IsMptErrorCode.unsupported);
      expect(res.verifications, isEmpty, reason: 'no fabricated CIS status');
    });

    test('verify offline (decorator) is honestly queued, not faked', () async {
      final inner = _ControllableIsMpt()..online = false;
      final provider = _wrap(inner, InMemoryIsMptQueueStore());
      final res = await provider.verifyCodes([_code1]);
      expect(res.success, isFalse);
      expect(res.queued, isTrue);
      expect(res.errorCode, IsMptErrorCode.network);
      expect(inner.verified, isEmpty, reason: 'offline → never called');
    });
  });

  group('Aggregation and re-marking', () {
    test('aggregate re-points children under a parent box code', () async {
      final inner = _ControllableIsMpt()..online = true;
      final svc = MarkingLifecycleService(
        db: db,
        ismpt: _wrap(inner, InMemoryIsMptQueueStore()),
      );

      await svc.acceptOnReceipt(
        ucode: 1,
        supplyId: 1,
        codes: const [_code1, _codeTobacco],
        submitRemote: false,
      );

      const box = '00046070012345678';
      final res = await svc.aggregate(
        parentCode: box,
        childCodes: const [_code1, _codeTobacco],
        parentLevel: 1,
        ucode: 1,
      );
      expect(res.affected, 2);

      final parent = await db.markingCodeDao.findByCode(box);
      expect(parent, isNotNull);
      expect(parent!.aggregationLevel, 1, reason: 'box level');
      final children = await db.markingCodeDao.findChildren(parent.id);
      expect(
        children.length,
        2,
        reason: 'both units now point at the parent box',
      );
      expect(inner.submitted, contains('aggr-$box'));
    });

    test(
      're-marking retires the old code, puts the new one in circulation',
      () async {
        final inner = _ControllableIsMpt()..online = true;
        final svc = MarkingLifecycleService(
          db: db,
          ismpt: _wrap(inner, InMemoryIsMptQueueStore()),
        );

        await svc.acceptOnReceipt(
          ucode: 7,
          supplyId: 1,
          codes: const [_code1],
          submitRemote: false,
        );

        const newCode = '0104607001234567219REPLACED1';
        final res = await svc.remark(oldCode: _code1, newCode: newCode);
        expect(res.localOk, isTrue);

        final old = await db.markingCodeDao.findByCode(_code1);
        expect(old!.status, MarkingStatus.retired.index);
        final fresh = await db.markingCodeDao.findByCode(newCode);
        expect(fresh, isNotNull);
        expect(fresh!.status, MarkingStatus.inStock.index);
        expect(fresh.ucode, 7, reason: 'inherits the old product ucode');
      },
    );
  });

  group('Offline-queue decorator + honest skeleton', () {
    test(
      'submitDocument offline is enqueued and returns queued-success',
      () async {
        final inner = _ControllableIsMpt()..online = false;
        final store = InMemoryIsMptQueueStore();
        final provider = _wrap(inner, store);

        final r = await provider.submitDocument(
          IsMptDocRequest(
            idempotencyKey: 'A-1',
            type: IsMptDocType.acceptance,
            codes: const [_code1],
          ),
        );
        expect(r.success, isTrue);
        expect(r.queued, isTrue);
        expect(inner.submitted, isEmpty);
        expect(await store.pendingCount(), 1);
      },
    );

    test('a thrown transport error queues instead of propagating', () async {
      final inner = _ControllableIsMpt()
        ..online = true
        ..throwOnSubmit = true;
      final store = InMemoryIsMptQueueStore();
      final provider = _wrap(inner, store);

      final r = await provider.submitDocument(
        IsMptDocRequest(
          idempotencyKey: 'A-THROW',
          type: IsMptDocType.withdrawal,
          codes: const [_code1],
        ),
      );
      expect(r.queued, isTrue);
      expect(await store.pendingCount(), 1);
    });

    test(
      'transient network queues; hard reject surfaces (not queued)',
      () async {
        final inner = _ControllableIsMpt()..online = true;
        final store = InMemoryIsMptQueueStore();
        final provider = _wrap(inner, store);

        inner.nextSubmit = IsMptResult.failure(
          'net',
          code: IsMptErrorCode.network,
        );
        final transient = await provider.submitDocument(
          IsMptDocRequest(
            idempotencyKey: 'A-NET',
            type: IsMptDocType.acceptance,
            codes: const [_code1],
          ),
        );
        expect(transient.queued, isTrue);
        expect(await store.pendingCount(), 1);

        inner.nextSubmit = IsMptResult.failure(
          'bad',
          code: IsMptErrorCode.rejected,
        );
        final hard = await provider.submitDocument(
          IsMptDocRequest(
            idempotencyKey: 'A-REJ',
            type: IsMptDocType.acceptance,
            codes: const [_code1],
          ),
        );
        expect(hard.success, isFalse);
        expect(hard.queued, isFalse);
        expect(hard.errorCode, IsMptErrorCode.rejected);
        expect(await store.pendingCount(), 1, reason: 'hard reject not queued');
      },
    );

    test(
      'replay drains FIFO with the ORIGINAL GUID and dedups idempotently',
      () async {
        final inner = _ControllableIsMpt()..online = false;
        final store = InMemoryIsMptQueueStore();
        final provider = _wrap(inner, store);

        await provider.submitDocument(
          IsMptDocRequest(
            idempotencyKey: 'B',
            type: IsMptDocType.acceptance,
            codes: const [_code1],
            occurredAt: DateTime(2026, 6, 1, 12, 2),
          ),
        );
        await provider.submitDocument(
          IsMptDocRequest(
            idempotencyKey: 'A',
            type: IsMptDocType.acceptance,
            codes: const [_code1],
            occurredAt: DateTime(2026, 6, 1, 12, 1),
          ),
        );
        expect(await store.pendingCount(), 2);

        inner.online = true;
        final report = await provider.replay();
        expect(report.submitted, 2);
        expect(report.remaining, 0);
        expect(inner.submitted, ['A', 'B'], reason: 'FIFO by occurredAt');

        inner.online = false;
        await provider.submitDocument(
          IsMptDocRequest(
            idempotencyKey: 'A',
            type: IsMptDocType.acceptance,
            codes: const [],
          ),
        );
        await provider.submitDocument(
          IsMptDocRequest(
            idempotencyKey: 'A',
            type: IsMptDocType.acceptance,
            codes: const [],
          ),
        );
        expect(await store.pendingCount(), 1);
      },
    );

    test('replay stops on network error, preserves the queue', () async {
      final inner = _ControllableIsMpt()..online = false;
      final store = InMemoryIsMptQueueStore();
      final provider = _wrap(inner, store);

      await provider.submitDocument(
        IsMptDocRequest(
          idempotencyKey: 'N-1',
          type: IsMptDocType.acceptance,
          codes: const [_code1],
          occurredAt: DateTime(2026, 6, 1, 12, 1),
        ),
      );
      await provider.submitDocument(
        IsMptDocRequest(
          idempotencyKey: 'N-2',
          type: IsMptDocType.acceptance,
          codes: const [_code1],
          occurredAt: DateTime(2026, 6, 1, 12, 2),
        ),
      );

      inner.online = true;
      var calls = 0;
      final flaky = _NetOnSecond(inner, () => calls++ == 1);
      final provider2 = IsMptOfflineQueueingProvider(
        inner: flaky,
        store: store,
        isReachable: () async => true,
      );
      final report = await provider2.replay();
      expect(report.submitted, 1);
      expect(report.stoppedOnNetwork, isTrue);
      expect(await store.pendingCount(), 1);
    });

    test('registry resolves backend → NoOp fallback when not registered '
        '(account-gated keeps POS selling offline)', () async {
      final registry = IsMptProviderRegistry();
      expect(registry.resolve(IsMptBackend.none), isA<RefusingIsMptProvider>());
      expect(registry.resolve(IsMptBackend.live), isA<RefusingIsMptProvider>());

      registry.register(IsMptBackend.live, () => const RefusingIsMptProvider());
      expect(registry.resolve(IsMptBackend.live), isA<RefusingIsMptProvider>());
    });

    test(
      'DI-resolved IsMptService is registered, resolvable and honest',
      () async {
        final h = E2eHarness();
        await h.setUp();
        addTearDown(() => h.tearDown());

        expect(GetIt.I.isRegistered<IsMptService>(), isTrue);
        final svc = GetIt.I<IsMptService>();
        expect(svc, isNotNull);
        expect(svc, isA<IsMptOfflineQueueingProvider>());
        final status = await svc.getStatus();
        expect(status, isNotNull);

        final registry = GetIt.I<IsMptProviderRegistry>();
        expect(
          registry.isRegistered(IsMptBackend.live),
          isTrue,
          reason: 'live backend binds a real provider (WebKassaIsMptProvider)',
        );
        expect(
          registry.resolve(IsMptBackend.live),
          isNot(isA<RefusingIsMptProvider>()),
          reason: 'live resolves to the real provider, not NoOp',
        );
      },
    );

    test('DataMatrix parser extracts GTIN/serial from raw GS1 code', () {
      final p = MarkingLifecycleService.parseDataMatrix(
        '010460700123456721ABC123',
      );
      expect(p.gtin, '04607001234567');
      expect(p.serial, 'ABC123');

      final hr = MarkingLifecycleService.parseDataMatrix(
        '(01)04607001234567(21)SN9',
      );
      expect(hr.gtin, '04607001234567');
      expect(hr.serial, 'SN9');
    });
  });
}

class _NetOnSecond implements IsMptService {
  _NetOnSecond(this._delegate, this._failNow);
  final _ControllableIsMpt _delegate;
  final bool Function() _failNow;

  @override
  String get id => _delegate.id;
  @override
  IsMptCapabilities get capabilities => _delegate.capabilities;
  @override
  Future<IsMptResult> authorize() => _delegate.authorize();
  @override
  Future<IsMptVerifyResult> verifyCodes(
    List<String> codes, {
    String? productGroup,
  }) => _delegate.verifyCodes(codes, productGroup: productGroup);
  @override
  Future<IsMptStatus> getStatus() => _delegate.getStatus();

  @override
  Future<IsMptResult> submitDocument(IsMptDocRequest req) async {
    if (_failNow()) {
      return IsMptResult.failure('net', code: IsMptErrorCode.network);
    }
    return _delegate.submitDocument(req);
  }
}
