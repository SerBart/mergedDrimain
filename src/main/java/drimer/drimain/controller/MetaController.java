package drimer.drimain.controller;

import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.List;
import java.util.HashSet;
import java.util.Set;

import lombok.RequiredArgsConstructor;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import drimer.drimain.api.dto.SimpleDzialDTO;
import drimer.drimain.api.dto.SimpleMaszynaDTO;
import drimer.drimain.api.dto.SimpleOsobaDTO;
import drimer.drimain.api.dto.SimpleSekcjaDTO;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.api.dto.DzialDTO;
import drimer.drimain.api.dto.MaszynaSelectDTO;
import drimer.drimain.api.dto.SekcjaDTO;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.model.Osoba;
import drimer.drimain.model.Maszyna;
import drimer.drimain.repository.SekcjaRepository;
import org.springframework.transaction.annotation.Transactional;

import drimer.drimain.api.dto.DashboardKpiDTO;
import drimer.drimain.model.Raport;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.repository.ZgloszenieRepository;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/meta")
@RequiredArgsConstructor
public class MetaController {

    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;
    private final DzialRepository dzialRepository;
    private final SekcjaRepository sekcjaRepository;
    private final UserRepository userRepository;
    private final RaportRepository raportRepository;
    private final ZgloszenieRepository zgloszenieRepository;

    @GetMapping("/statusy/raporty")
    public List<String> raportStatuses() {
        return Arrays.stream(RaportStatus.values()).map(Enum::name).toList();
    }

    @GetMapping("/statusy/zgloszenia")
    public List<String> zgloszenieStatuses() {
        return Arrays.stream(ZgloszenieStatus.values()).map(Enum::name).toList();
    }

    // Proste listy do formularzy (bez ograniczenia do ADMIN)
    @GetMapping("/maszyny-simple")
    public List<SimpleMaszynaDTO> simpleMaszyny(
            @RequestParam(name = "dzialId", required = false) Long dzialId,
            @RequestParam(name = "dzialNazwa", required = false) String dzialNazwa
    ) {
        List<Maszyna> maszyn;
        if (dzialId != null) {
            maszyn = maszynaRepository.findByDzial_Id(dzialId);
        } else if (dzialNazwa != null && !dzialNazwa.isBlank()) {
            maszyn = maszynaRepository.findByDzial_NazwaIgnoreCase(dzialNazwa.trim());
        } else {
            maszyn = maszynaRepository.findAll();
        }
        return maszyn.stream().map(m -> {
            SimpleMaszynaDTO dto = new SimpleMaszynaDTO();
            dto.setId(m.getId());
            dto.setNazwa(m.getNazwa());
            if (m.getDzial() != null) {
                SimpleDzialDTO d = new SimpleDzialDTO();
                d.setId(m.getDzial().getId());
                d.setNazwa(m.getDzial().getNazwa());
                dto.setDzial(d);
            }
            if (m.getSekcja() != null) {
                SimpleSekcjaDTO s = new SimpleSekcjaDTO();
                s.setId(m.getSekcja().getId());
                s.setNazwa(m.getSekcja().getNazwa());
                dto.setSekcja(s);
            }
            return dto;
        }).toList();
    }

    @GetMapping("/osoby-simple")
    public List<SimpleOsobaDTO> simpleOsoby(
            @RequestParam(name = "dzialId", required = false) Long dzialId,
            @RequestParam(name = "dzialNazwa", required = false) String dzialNazwa
    ) {
        // Zbierz istniejące loginy Osób
        Set<String> existing = new HashSet<>();
        osobaRepository.findAll().forEach(o -> {
            if (o.getLogin() != null && !o.getLogin().isBlank()) existing.add(o.getLogin());
        });
        // Dla każdego użytkownika bez odpowiadającej Osoby - utwórz wpis Osoba (login=username)
        userRepository.findAll().forEach(u -> {
            String uname = u.getUsername();
            if (uname != null && !uname.isBlank() && !existing.contains(uname)) {
                Osoba nowa = new Osoba();
                nowa.setLogin(uname);
                // imie+nazwisko ustawiamy na username, dopóki nie zostanie uzupełnione inaczej
                nowa.setImieNazwisko(uname);
                nowa.setHaslo(null);
                nowa.setRola(null);
                // UWAGA: nowa osoba nie dostaje działu automatycznie.
                osobaRepository.save(nowa);
                existing.add(uname);
            }
        });

        // Zastosuj filtr po dziale jeśli podano; inaczej domyślnie ogranicz do „Utrzymanie Ruchu”.
        List<Osoba> osoby;
        if (dzialId != null) {
            osoby = osobaRepository.findByDzial_Id(dzialId);
        } else if (dzialNazwa != null && !dzialNazwa.isBlank()) {
            osoby = osobaRepository.findByDzial_NazwaIgnoreCase(dzialNazwa.trim());
        } else {
            // DOMYŚLNIE: tylko osoby z działu UR
            // Fallback: jeśli dział nie istnieje, zwróć pustą listę (czytelny brak wyboru w UI).
            String urName = "Utrzymanie Ruchu";
            osoby = osobaRepository.findByDzial_NazwaIgnoreCase(urName);
        }

        return osoby.stream().map(o -> {
            SimpleOsobaDTO dto = new SimpleOsobaDTO();
            dto.setId(o.getId());
            dto.setImieNazwisko(o.getImieNazwisko());
            return dto;
        }).toList();
    }

    @GetMapping("/dzialy-simple")
    public List<DzialDTO> simpleDzialy() {
        return dzialRepository.findAll().stream().map(d -> {
            DzialDTO dto = new DzialDTO();
            dto.setId(d.getId());
            dto.setNazwa(d.getNazwa());
            return dto;
        }).toList();
    }

    @GetMapping("/sekcje-simple")
    @Transactional(readOnly = true)
    public List<SekcjaDTO> simpleSekcje(@RequestParam(name = "dzialId", required = false) Long dzialId) {
        return (dzialId != null ? sekcjaRepository.findByDzial_IdOrderByNazwaAsc(dzialId) : sekcjaRepository.findAllByOrderByNazwaAsc())
                .stream()
                .map(s -> {
                    SekcjaDTO dto = new SekcjaDTO();
                    dto.setId(s.getId());
                    dto.setNazwa(s.getNazwa());
                    if (s.getDzial() != null) {
                        DzialDTO d = new DzialDTO();
                        d.setId(s.getDzial().getId());
                        d.setNazwa(s.getDzial().getNazwa());
                        dto.setDzial(d);
                    }
                    return dto;
                })
                .toList();
    }

    // Alias: lista maszyn w formacie kompatybilnym z UI select (id, name, label, nazwa)
    @GetMapping("/maszyny")
    public java.util.List<MaszynaSelectDTO> maszyny() {
        return maszynaRepository.findAll().stream().map(m -> {
            MaszynaSelectDTO dto = new MaszynaSelectDTO();
            dto.setId(m.getId());
            dto.setNazwa(m.getNazwa());
            dto.setName(m.getNazwa());
            dto.setLabel(m.getSekcja() != null ? (m.getNazwa() + " [" + m.getSekcja().getNazwa() + "]") : m.getNazwa());
            return dto;
        }).toList();
    }

    @GetMapping("/dashboard-kpi")
    @Transactional(readOnly = true)
    public DashboardKpiDTO dashboardKpi() {
        LocalDate today = LocalDate.now();
        LocalDate sevenDaysAgo = today.minusDays(6);

        var raporty = raportRepository.findAll();
        var zgloszenia = zgloszenieRepository.findAll();

        DashboardKpiDTO dto = new DashboardKpiDTO();

        dto.setRaportyDzis(raporty.stream()
                .map(Raport::getDataNaprawy)
                .filter(d -> d != null && d.equals(today))
                .count());

        dto.setRaporty7Dni(raporty.stream()
                .map(Raport::getDataNaprawy)
                .filter(d -> d != null && !d.isBefore(sevenDaysAgo))
                .count());

        dto.setZgloszeniaDzisNowe(countTodayByStatus(zgloszenia, today, ZgloszenieStatus.OPEN));
        dto.setZgloszeniaDzisWToku(countTodayByStatus(zgloszenia, today, ZgloszenieStatus.IN_PROGRESS));
        dto.setZgloszeniaDzisZamkniete(countTodayByStatus(zgloszenia, today, ZgloszenieStatus.DONE));

        double avgHours = zgloszenia.stream()
                .filter(z -> z.getStatus() == ZgloszenieStatus.DONE)
                .filter(z -> z.getAcceptedAt() != null && z.getCompletedAt() != null)
                .mapToLong(z -> Duration.between(z.getAcceptedAt(), z.getCompletedAt()).toMinutes())
                .average()
                .orElse(0.0) / 60.0;
        dto.setSredniCzasRozwiazaniaGodziny(Math.round(avgHours * 10.0) / 10.0);

        long maszynyRazem = maszynaRepository.count();
        long maszynyWPrzestoju = zgloszenia.stream()
                .filter(z -> z.getMaszyna() != null && z.getMaszyna().getId() != null)
                .filter(z -> z.getStatus() != ZgloszenieStatus.DONE && z.getStatus() != ZgloszenieStatus.REJECTED)
                .map(z -> z.getMaszyna().getId())
                .distinct()
                .count();
        dto.setMaszynyRazem(maszynyRazem);
        dto.setMaszynyWPrzestoju(maszynyWPrzestoju);
        dto.setMaszynyWPracy(Math.max(0, maszynyRazem - maszynyWPrzestoju));

        Map<String, Long> topTypy = zgloszenia.stream()
                .map(Zgloszenie::getTyp)
                .filter(t -> t != null && !t.isBlank())
                .collect(Collectors.groupingBy(t -> t, Collectors.counting()))
                .entrySet()
                .stream()
                .sorted(Map.Entry.<String, Long>comparingByValue(Comparator.reverseOrder()))
                .limit(3)
                .collect(Collectors.toMap(
                        Map.Entry::getKey,
                        Map.Entry::getValue,
                        (a, b) -> a,
                        LinkedHashMap::new
                ));
        dto.setTopTypyZgloszen(topTypy);

        Map<String, Long> zglByStatus = new LinkedHashMap<>();
        for (ZgloszenieStatus status : ZgloszenieStatus.values()) {
            long count = zgloszenia.stream().filter(z -> z.getStatus() == status).count();
            zglByStatus.put(status.name(), count);
        }
        dto.setZgloszeniaByStatus(zglByStatus);

        Map<String, Long> raportyByStatus = new LinkedHashMap<>();
        for (RaportStatus status : RaportStatus.values()) {
            long count = raporty.stream().filter(r -> r.getStatus() == status).count();
            raportyByStatus.put(status.name(), count);
        }
        dto.setRaportyByStatus(raportyByStatus);

        dto.setLastUpdated(LocalDateTime.now());
        return dto;
    }

    private long countTodayByStatus(List<Zgloszenie> zgloszenia, LocalDate today, ZgloszenieStatus targetStatus) {
        return zgloszenia.stream()
                .filter(z -> z.getStatus() == targetStatus)
                .filter(z -> {
                    LocalDateTime ts = z.getDataGodzina() != null ? z.getDataGodzina() : z.getCreatedAt();
                    return ts != null && ts.toLocalDate().equals(today);
                })
                .count();
    }
}