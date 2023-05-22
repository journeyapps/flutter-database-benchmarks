import 'dart:io';
import 'dart:math';

import './util.dart';
import '../interface/benchmark.dart';
import '../model/isar_t1.dart';
import '../model/isar_t2.dart';
import '../model/isar_t3.dart';
import 'package:isar/isar.dart';

class IsarDBImpl extends Benchmark {
  late Isar isar;
  final String path;

  IsarDBImpl(this.path);

  final random = Random(0);

  @override
  String get name => 'Isar';

  @override
  Future<void> setUp() async {
    isar = await Isar.open([IsarT1Schema, IsarT2Schema, IsarT3Schema],
        directory: path, relaxedDurability: true);

    await isar.writeTxn(() async {
      await isar.clear();
    });
  }

  @override
  Future<void> tearDown() async {
    await isar.close();
  }

  @override
  Future<int> getDbSize() async {
    final files = Directory(path)
        .listSync(recursive: true)
        .where((file) => file.path.toLowerCase().contains('isar'));
    int size = 0;
    for (FileSystemEntity file in files) {
      final stat = file.statSync();
      size += stat.size;
    }
    return size;
  }

  @override
  Future<void> test1() async {
    final t1 = isar.isarT1s;
    for (var i = 0; i < 1000; i++) {
      final n = random.nextInt(100000);

      await isar.writeTxn(() async {
        await t1.put(IsarT1(a: i + 1, b: n, c: numberName(n)));
      });
    }
  }

  @override
  Future<void> test2() async {
    final t2 = isar.isarT2s;
    await isar.writeTxn(() async {
      for (var i = 0; i < 25000; ++i) {
        final n = random.nextInt(100000);
        await t2.put(IsarT2(a: i + 1, b: n, c: numberName(n)));
      }
    });
  }

  @override
  Future<void> test3() async {
    final t3 = isar.isarT3s;
    await isar.writeTxn(() async {
      for (int i = 0; i < 25000; ++i) {
        final n = random.nextInt(100000);
        await t3.put(IsarT3(a: i + 1, b: n, c: numberName(n)));
      }
    });
  }

  @override
  Future<void> test4() async {
    await isar.txn(() async {
      var t2 = isar.isarT2s;
      for (int i = 0; i < 100; ++i) {
        final query =
            t2.filter().bBetween(i * 100, i * 100 + 1000, includeUpper: false);

        final count = await query.count();
        final avg = await query.bProperty().average();

        assertAlways(count > 200);
        assertAlways(count < 300);

        assertAlways(avg > i * 100);
        assertAlways(avg < i * 100 + 1000);
      }
    });
  }

  @override
  Future<void> test5() async {
    final t2 = isar.isarT2s;
    await isar.txn(() async {
      for (int i = 0; i < 100; ++i) {
        final query = t2.filter().cMatches('*${numberName(i + 1)}*');

        final count = await query.count();
        final avg = await query.bProperty().average();

        assertAlways(count > 400);
        assertAlways(count < 12000);
        assertAlways(avg > 30000);
      }
    });
  }

  @override
  Future<void> test6() async {
    // Isar automatically creates indexes
  }
  @override
  Future<void> test7() async {
    final t3 = isar.isarT3s;
    await isar.txn(() async {
      for (int i = 0; i < 5000; ++i) {
        final query = await t3
            .where()
            .bBetween(i * 100, i * 100 + 100, includeUpper: false);
        final count = await query.count();
        final avg = await query.bProperty().average();

        if (i < 1000) {
          assertAlways(count > 10);
          assertAlways(count < 100);
        } else {
          assertAlways(count == 0);
        }
      }
    });
  }

  @override
  Future<void> test8() async {
    final t1 = isar.isarT1s;
    await isar.writeTxn(() async {
      for (int i = 0; i < 1000; ++i) {
        final objs = await t1
            .filter()
            .aBetween(i * 10, i * 10 + 10, includeUpper: false)
            .findAll();
        for (final obj in objs) {
          obj.b *= 2;
          await t1.put(obj);
        }
      }
    });
  }

  @override
  Future<void> test9() async {
    final t3 = isar.isarT3s;
    await isar.writeTxn(() async {
      for (int i = 0; i < 25000; ++i) {
        final n = random.nextInt(100000);
        var obj = await t3.getByIndex('a', [i + 1]);
        obj!.b = n;
        await t3.put(obj);
      }
    });
  }

  @override
  Future<void> test10() async {
    final t3 = isar.isarT3s;
    await isar.writeTxn(() async {
      for (int i = 0; i < 25000; ++i) {
        final n = random.nextInt(100000);
        var obj = await t3.getByIndex('a', [i + 1]);
        obj!.c = numberName(n);
        await t3.put(obj);
      }
    });
  }

  @override
  Future<void> test11() async {
    final t1 = isar.isarT1s;
    final t3 = isar.isarT3s;
    await isar.writeTxn(() async {
      final t3List = await t3.where().findAll();
      await t1.putAll(
          t3List.map((obj) => IsarT1(a: obj.b, b: obj.a, c: obj.c)).toList());

      final t1List = await t1.where().findAll();
      await t3.putAll(
          t1List.map((obj) => IsarT3(a: obj.b, b: obj.a!, c: obj.c)).toList());
    });
  }

  @override
  Future<void> test12() async {
    final t3 = isar.isarT3s;
    await isar.writeTxn(() async {
      await t3.filter().cMatches('*fifty*').deleteAll();
    });
  }

  @override
  Future<void> test13() async {
    final t3 = isar.isarT3s;
    await isar.writeTxn(() async {
      await t3
          .where()
          .aBetween(10, 20000, includeLower: false, includeUpper: false)
          .deleteAll();
    });
  }

  @override
  Future<void> test14() async {
    final t1 = isar.isarT1s;
    final t3 = isar.isarT3s;
    await isar.writeTxn(() async {
      final t1List = await t1.where().findAll();
      await t3.putAll(
          t1List.map((obj) => IsarT3(a: obj.a!, b: obj.b, c: obj.c)).toList());
    });
  }

  @override
  Future<void> test15() async {
    final t1 = isar.isarT1s;
    await isar.writeTxn(() async {
      await t1.clear();
      for (int i = 0; i < 12000; ++i) {
        final n = random.nextInt(100000);
        await t1.put(IsarT1(a: i + 1, b: n, c: numberName(n)));
      }
    });
  }

  @override
  Future<void> test16() async {
    var count1 = await isar.isarT1s.count();
    var count2 = await isar.isarT2s.count();
    var count3 = await isar.isarT3s.count();
    assertAlways(count1 == 12000);
    assertAlways(count2 == 25000);
    assertAlways(count3 > 34000);
    assert(count3 < 36000);
    await isar.writeTxn(() async {
      await isar.isarT1s.clear();
      await isar.isarT2s.clear();
      await isar.isarT3s.clear();
    });
  }
}
