import 'package:collection/collection.dart';
import '../models/raport.dart';
import '../models/maszyna.dart';

import '../models/dzial.dart';
import '../models/osoba.dart';
import '../models/zgloszenie.dart';
import '../models/user.dart';
import '../models/part.dart';
import '../models/part_usage.dart';

class MockRepository {
  int _raportId = 0;
  int _zgloszenieId = 0;
  int _dzialId = 0;
  int _maszynaId = 0;
  int _osobaId = 0;
  int _userId = 0;
  int _partId = 0;

  // Puste listy – będą zasilane z backendu (meta/admin API)
  final List<Dzial> dzialy = [];
  final List<Maszyna> maszyny = [];
  final List<Osoba> osoby = [];

  // Użytkownicy i części mogą pozostać jako lokalne struktury pomocnicze
  final List<User> users = [
    User(id: 1, username: 'admin', role: 'ADMIN', token: null),
    User(id: 2, username: 'user', role: 'USER', token: null),
  ];

  final List<Zgloszenie> zgloszenia = [];

  final List<Part> parts = [
    Part(id: 1, nazwa: 'Łożysko 6204', kod: 'BRG-6204', iloscMagazyn: 12, minIlosc: 5, jednostka: 'szt', kategoria: 'Łożyska'),
    Part(id: 2, nazwa: 'Pasek klinowy A36', kod: 'BELT-A36', iloscMagazyn: 4, minIlosc: 3, jednostka: 'szt', kategoria: 'Paski'),
    Part(id: 3, nazwa: 'Olej hydrauliczny HLP46', kod: 'OIL-H46', iloscMagazyn: 60, minIlosc: 20, jednostka: 'l', kategoria: 'Oleje'),
  ];

  final List<Raport> raporty = [];

  MockRepository();

  // GET
  List<Raport> getRaporty() => List.unmodifiable(raporty);
  List<Zgloszenie> getZgloszenia() => List.unmodifiable(zgloszenia);
  List<Dzial> getDzialy() => List.unmodifiable(dzialy);
  List<Maszyna> getMaszyny() => List.unmodifiable(maszyny);
  List<Osoba> getOsoby() => List.unmodifiable(osoby);
  List<User> getUsers() => List.unmodifiable(users);
  List<Part> getParts() => List.unmodifiable(parts);

  Raport? getRaportById(int id) => raporty.firstWhereOrNull((e) => e.id == id);

  // RAPORTY
  Raport upsertRaport(Raport r) {
    if (r.id == 0) {
      _raportId++;
      final newRaport = r.copyWith(id: _raportId);
      raporty.add(newRaport);
      return newRaport;
    } else {
      final idx = raporty.indexWhere((e) => e.id == r.id);
      if (idx != -1) {
        raporty[idx] = r;
        return r;
      } else {
        raporty.add(r);
        return r;
      }
    }
  }

  bool deleteRaport(int id) {
    final before = raporty.length;
    raporty.removeWhere((r) => r.id == id);
    return raporty.length < before;
  }

  void addPartUsageToRaport(int raportId, Part part, int ilosc) {
    final raport = getRaportById(raportId);
    if (raport == null) return;
    if (part.iloscMagazyn < ilosc) {
      throw Exception('Za mało w magazynie');
    }
    part.iloscMagazyn -= ilosc;
    final updated = raport.copyWith(
      partUsages: [...raport.partUsages, PartUsage(part: part, ilosc: ilosc)],
    );
    upsertRaport(updated);
  }

  Zgloszenie addZgloszenie(Zgloszenie z) {
    _zgloszenieId++;
    final newZ = z.copyWith(id: _zgloszenieId);
    zgloszenia.add(newZ);
    return newZ;
  }

  Zgloszenie? getZgloszenieById(int id) =>
      zgloszenia.firstWhereOrNull((e) => e.id == id);

  Zgloszenie updateZgloszenie(Zgloszenie updated) {
    final idx = zgloszenia.indexWhere((e) => e.id == updated.id);
    if (idx == -1) {
      zgloszenia.add(updated.copyWith());
      return updated;
    }
    zgloszenia[idx] = updated.copyWith(); // ustawi nowy lastUpdated
    return zgloszenia[idx];
  }

  bool deleteZgloszenie(int id) {
    final before = zgloszenia.length;
    zgloszenia.removeWhere((z) => z.id == id);
    return zgloszenia.length < before;
  }

  List<Zgloszenie> searchZgloszenia(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(zgloszenia);
    return zgloszenia.where((z) {
      return z.typ.toLowerCase().contains(q) ||
          z.opis.toLowerCase().contains(q) ||
          z.imie.toLowerCase().contains(q) ||
          z.nazwisko.toLowerCase().contains(q) ||
          z.status.toLowerCase().contains(q) ||
          z.id.toString() == q;
    }).toList()
      ..sort((a, b) => b.dataGodzina.compareTo(a.dataGodzina));
  }

  // DZIAŁ
  Dzial addDzial(String nazwa) {
    _dzialId++;
    final d = Dzial(id: _dzialId, nazwa: nazwa);
    dzialy.add(d);
    return d;
  }

  bool deleteDzial(int id) {
    final before = dzialy.length;
    dzialy.removeWhere((d) => d.id == id);
    maszyny.removeWhere((m) => m.dzial?.id == id);
    return dzialy.length < before;
  }

  // MASZYNA
  Maszyna addMaszyna(String nazwa, int dzialId) {
    _maszynaId++;
    final dz = dzialy.firstWhereOrNull((d) => d.id == dzialId);
    final m = Maszyna(id: _maszynaId, nazwa: nazwa, dzial: dz);
    maszyny.add(m);
    return m;
  }

  bool deleteMaszyna(int id) {
    final before = maszyny.length;
    maszyny.removeWhere((m) => m.id == id);
    return maszyny.length < before;
  }

  // OSOBA
  Osoba addOsoba(String imieNazwisko) {
    _osobaId++;
    final o = Osoba(id: _osobaId, imieNazwisko: imieNazwisko);
    osoby.add(o);
    return o;
  }

  bool deleteOsoba(int id) {
    final before = osoby.length;
    osoby.removeWhere((o) => o.id == id);
    return osoby.length < before;
  }

  // USER
  User addUser(String username, String role) {
    _userId++;
    final u = User(id: _userId, username: username, role: role);
    users.add(u);
    return u;
  }

  bool deleteUser(int id) {
    final before = users.length;
    users.removeWhere((u) => u.id == id);
    return users.length < before;
  }

  Part addPart({
    required String nazwa,
    required String kod,
    required int ilosc,
    required int minIlosc,
    required String jednostka,
    String? kategoria,
  }) {
    _partId++;
    final p = Part(
      id: _partId,
      nazwa: nazwa,
      kod: kod,
      iloscMagazyn: ilosc,
      minIlosc: minIlosc,
      jednostka: jednostka,
      kategoria: kategoria,
    );
    parts.add(p);
    return p;
  }

  bool deletePart(int id) {
    final before = parts.length;
    parts.removeWhere((p) => p.id == id);
    return parts.length < before;
  }

  Part? getPartById(int id) => parts.firstWhereOrNull((p) => p.id == id);

  Part updatePart(Part updated) {
    final idx = parts.indexWhere((p) => p.id == updated.id);
    if (idx == -1) {
      parts.add(updated);
      return updated;
    }
    parts[idx] = updated;
    return updated;
  }

  Part? adjustPartQuantity(int id, int delta) {
    final part = getPartById(id);
    if (part == null) return null;
    final newQty = part.iloscMagazyn + delta;
    if (newQty < 0) {
      throw Exception('Ilość nie może być ujemna');
    }
    part.iloscMagazyn = newQty;
    return part;
  }
}