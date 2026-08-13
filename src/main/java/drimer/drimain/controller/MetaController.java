package drimer.drimain.controller;

import drimer.drimain.model.enums.RaportStatus;
import drimer.drimain.model.enums.ZgloszenieStatus;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
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
import drimer.drimain.api.dto.DashboardTrendPointDTO;
import drimer.drimain.model.Raport;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.repository.RaportRepository;
import drimer.drimain.repository.ZgloszenieRepository;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
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
    public DashboardKpiDTO dashboardKpi(@RequestParam(name = "days", defaultValue = "7") int days) {
        int normalizedDays = normalizeDays(days);
        LocalDate today = LocalDate.now();
        LocalDate periodStart = today.minusDays(normalizedDays - 1L);
        LocalDate previousPeriodEnd = periodStart.minusDays(1);
        LocalDate previousPeriodStart = previousPeriodEnd.minusDays(normalizedDays - 1L);
        LocalDateTime periodStartAt = periodStart.atStartOfDay();
        LocalDateTime periodEndExclusive = today.plusDays(1).atStartOfDay();
        LocalDateTime previousStartAt = previousPeriodStart.atStartOfDay();
        LocalDateTime previousEndExclusive = periodStart.atStartOfDay();

        var raporty = raportRepository.findAll();
        var zgloszenia = zgloszenieRepository.findAll();

        DashboardKpiDTO dto = new DashboardKpiDTO();
        dto.setZakresDni(normalizedDays);
        dto.setOkresOd(periodStart);
        dto.setOkresDo(today);

        dto.setRaportyWOkresie(raporty.stream()
                .map(Raport::getDataNaprawy)
                .filter(d -> isInDateRange(d, periodStart, today))
                .count());

        dto.setZgloszeniaWOkresieNowe(countByStatusInRange(zgloszenia, periodStartAt, periodEndExclusive, ZgloszenieStatus.OPEN));
        dto.setZgloszeniaWOkresieWToku(countByStatusInRange(zgloszenia, periodStartAt, periodEndExclusive, ZgloszenieStatus.IN_PROGRESS));
        dto.setZgloszeniaWOkresieZamkniete(countByStatusInRange(zgloszenia, periodStartAt, periodEndExclusive, ZgloszenieStatus.DONE));

        dto.setZgloszeniaWPoprzednimOkresie(zgloszenia.stream()
                .filter(z -> isInDateTimeRange(resolveZgloszenieTimestamp(z), previousStartAt, previousEndExclusive))
                .count());

        dto.setRaportyWPoprzednimOkresie(raporty.stream()
                .map(Raport::getDataNaprawy)
                .filter(d -> isInDateRange(d, previousPeriodStart, previousPeriodEnd))
                .count());

        dto.setZgloszeniaZmianaProcent(percentChange(dto.getZgloszeniaWOkresieNowe(), dto.getZgloszeniaWPoprzednimOkresie()));
        dto.setRaportyZmianaProcent(percentChange(dto.getRaportyWOkresie(), dto.getRaportyWPoprzednimOkresie()));

        dto.setZgloszeniaTrend(buildZgloszenieTrend(zgloszenia, periodStart, today));
        dto.setRaportyTrend(buildRaportTrend(raporty, periodStart, today));

        dto.setRaportyDzis(raporty.stream()
                .map(Raport::getDataNaprawy)
                .filter(d -> d != null && d.equals(today))
                .count());

        dto.setRaporty7Dni(raporty.stream()
                .map(Raport::getDataNaprawy)
                .filter(d -> d != null && !d.isBefore(today.minusDays(6)))
                .count());

        dto.setZgloszeniaDzisNowe(countTodayByStatus(zgloszenia, today, ZgloszenieStatus.OPEN));
        dto.setZgloszeniaDzisWToku(countTodayByStatus(zgloszenia, today, ZgloszenieStatus.IN_PROGRESS));
        dto.setZgloszeniaDzisZamkniete(countTodayByStatus(zgloszenia, today, ZgloszenieStatus.DONE));

        double avgHours = zgloszenia.stream()
                .filter(z -> z.getStatus() == ZgloszenieStatus.DONE)
                .filter(z -> z.getAcceptedAt() != null && z.getCompletedAt() != null)
                .filter(z -> isInDateTimeRange(z.getCompletedAt(), periodStartAt, periodEndExclusive))
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
                .filter(z -> isInDateTimeRange(resolveZgloszenieTimestamp(z), periodStartAt, periodEndExclusive))
                .map(Zgloszenie::getTyp)
                .filter(t -> t != null && !t.isBlank())
                .collect(Collectors.groupingBy(t -> t, Collectors.counting()))
                .entrySet()
                .stream()
                .sorted(Map.Entry.comparingByValue(Comparator.reverseOrder()))
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
            long count = zgloszenia.stream()
                    .filter(z -> z.getStatus() == status)
                    .filter(z -> isInDateTimeRange(resolveZgloszenieTimestamp(z), periodStartAt, periodEndExclusive))
                    .count();
            zglByStatus.put(status.name(), count);
        }
        dto.setZgloszeniaByStatus(zglByStatus);

        Map<String, Long> raportyByStatus = new LinkedHashMap<>();
        for (RaportStatus status : RaportStatus.values()) {
            long count = raporty.stream()
                    .filter(r -> r.getStatus() == status)
                    .filter(r -> isInDateRange(r.getDataNaprawy(), periodStart, today))
                    .count();
            raportyByStatus.put(status.name(), count);
        }
        dto.setRaportyByStatus(raportyByStatus);

        dto.setLastUpdated(LocalDateTime.now());
        return dto;
    }

    @GetMapping(value = "/dashboard-kpi/export", produces = "text/csv")
    @Transactional(readOnly = true)
    public ResponseEntity<String> exportDashboardKpi(@RequestParam(name = "days", defaultValue = "7") int days) {
        DashboardKpiDTO dto = dashboardKpi(days);
        String csv = buildDashboardKpiCsv(dto);
        String filename = "dashboard-kpi-" + dto.getZakresDni() + "d.csv";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(new MediaType("text", "csv", StandardCharsets.UTF_8));
        headers.set(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");

        return ResponseEntity.ok()
                .headers(headers)
                .body(csv);
    }

    @GetMapping(value = "/dashboard-kpi/export.pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    @Transactional(readOnly = true)
    public ResponseEntity<byte[]> exportDashboardKpiPdf(@RequestParam(name = "days", defaultValue = "7") int days) throws IOException {
        DashboardKpiDTO dto = dashboardKpi(days);
        byte[] pdf = buildDashboardKpiPdf(dto);
        String filename = "dashboard-kpi-" + dto.getZakresDni() + "d.pdf";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_PDF);
        headers.set(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");

        return ResponseEntity.ok()
                .headers(headers)
                .body(pdf);
    }

    private long countTodayByStatus(List<Zgloszenie> zgloszenia, LocalDate today, ZgloszenieStatus targetStatus) {
        return zgloszenia.stream()
                .filter(z -> z.getStatus() == targetStatus)
                .filter(z -> {
                    LocalDateTime ts = resolveZgloszenieTimestamp(z);
                    return ts != null && ts.toLocalDate().equals(today);
                })
                .count();
    }

    private long countByStatusInRange(List<Zgloszenie> zgloszenia,
                                      LocalDateTime startInclusive,
                                      LocalDateTime endExclusive,
                                      ZgloszenieStatus targetStatus) {
        return zgloszenia.stream()
                .filter(z -> z.getStatus() == targetStatus)
                .filter(z -> isInDateTimeRange(resolveZgloszenieTimestamp(z), startInclusive, endExclusive))
                .count();
    }

    private LocalDateTime resolveZgloszenieTimestamp(Zgloszenie zgloszenie) {
        return zgloszenie.getDataGodzina() != null ? zgloszenie.getDataGodzina() : zgloszenie.getCreatedAt();
    }

    private boolean isInDateRange(LocalDate date, LocalDate startInclusive, LocalDate endInclusive) {
        return date != null && !date.isBefore(startInclusive) && !date.isAfter(endInclusive);
    }

    private boolean isInDateTimeRange(LocalDateTime value, LocalDateTime startInclusive, LocalDateTime endExclusive) {
        return value != null && !value.isBefore(startInclusive) && value.isBefore(endExclusive);
    }

    private int normalizeDays(int days) {
        if (days < 1) {
            return 1;
        }
        return Math.min(days, 30);
    }

    private String buildDashboardKpiCsv(DashboardKpiDTO dto) {
        StringBuilder sb = new StringBuilder();
        sb.append("sekcja;klucz;wartosc\n");

        appendCsv(sb, "meta", "zakresDni", dto.getZakresDni());
        appendCsv(sb, "meta", "okresOd", dto.getOkresOd());
        appendCsv(sb, "meta", "okresDo", dto.getOkresDo());
        appendCsv(sb, "meta", "lastUpdated", dto.getLastUpdated());

        appendCsv(sb, "kpi", "zgloszeniaWOkresieNowe", dto.getZgloszeniaWOkresieNowe());
        appendCsv(sb, "kpi", "zgloszeniaWOkresieWToku", dto.getZgloszeniaWOkresieWToku());
        appendCsv(sb, "kpi", "zgloszeniaWOkresieZamkniete", dto.getZgloszeniaWOkresieZamkniete());
        appendCsv(sb, "kpi", "raportyWOkresie", dto.getRaportyWOkresie());
        appendCsv(sb, "kpi", "zgloszeniaWPoprzednimOkresie", dto.getZgloszeniaWPoprzednimOkresie());
        appendCsv(sb, "kpi", "raportyWPoprzednimOkresie", dto.getRaportyWPoprzednimOkresie());
        appendCsv(sb, "kpi", "zgloszeniaZmianaProcent", dto.getZgloszeniaZmianaProcent());
        appendCsv(sb, "kpi", "raportyZmianaProcent", dto.getRaportyZmianaProcent());
        appendCsv(sb, "kpi", "sredniCzasRozwiazaniaGodziny", dto.getSredniCzasRozwiazaniaGodziny());
        appendCsv(sb, "kpi", "maszynyRazem", dto.getMaszynyRazem());
        appendCsv(sb, "kpi", "maszynyWPracy", dto.getMaszynyWPracy());
        appendCsv(sb, "kpi", "maszynyWPrzestoju", dto.getMaszynyWPrzestoju());

        dto.getTopTypyZgloszen().forEach((key, value) -> appendCsv(sb, "topTypyZgloszen", key, value));
        dto.getZgloszeniaByStatus().forEach((key, value) -> appendCsv(sb, "zgloszeniaByStatus", key, value));
        dto.getRaportyByStatus().forEach((key, value) -> appendCsv(sb, "raportyByStatus", key, value));

        dto.getZgloszeniaTrend().forEach(point -> appendCsv(sb, "zgloszeniaTrend", String.valueOf(point.getDate()), point.getCount()));
        dto.getRaportyTrend().forEach(point -> appendCsv(sb, "raportyTrend", String.valueOf(point.getDate()), point.getCount()));

        return sb.toString();
    }

    private void appendCsv(StringBuilder sb, String section, String key, Object value) {
        sb.append(csvEscape(section))
                .append(';')
                .append(csvEscape(key))
                .append(';')
                .append(csvEscape(value == null ? "" : String.valueOf(value)))
                .append('\n');
    }

    private String csvEscape(String value) {
        if (value == null) {
            return "";
        }
        String escaped = value.replace("\"", "\"\"");
        if (escaped.indexOf(';') >= 0 || escaped.indexOf('"') >= 0 || escaped.indexOf('\n') >= 0 || escaped.indexOf('\r') >= 0) {
            return '"' + escaped + '"';
        }
        return escaped;
    }

    private byte[] buildDashboardKpiPdf(DashboardKpiDTO dto) throws IOException {
        List<String> lines = new ArrayList<>();
        lines.add("Raport KPI");
        lines.add("Zakres: " + dto.getZakresDni() + " dni");
        lines.add("Okres: " + dto.getOkresOd() + " - " + dto.getOkresDo());
        lines.add("Aktualizacja: " + dto.getLastUpdated());
        lines.add("");
        lines.add("Kluczowe metryki");
        lines.add("- Nowe zgloszenia: " + dto.getZgloszeniaWOkresieNowe());
        lines.add("- Zgloszenia w toku: " + dto.getZgloszeniaWOkresieWToku());
        lines.add("- Zamkniete zgloszenia: " + dto.getZgloszeniaWOkresieZamkniete());
        lines.add("- Raporty: " + dto.getRaportyWOkresie());
        lines.add("- Sredni czas rozwiazania [h]: " + dto.getSredniCzasRozwiazaniaGodziny());
        lines.add("- Maszyny w przestoju: " + dto.getMaszynyWPrzestoju() + " / " + dto.getMaszynyRazem());
        lines.add("");
        lines.add("Top typy zgloszen");
        if (dto.getTopTypyZgloszen().isEmpty()) {
            lines.add("- Brak danych");
        } else {
            dto.getTopTypyZgloszen().forEach((k, v) -> lines.add("- " + k + ": " + v));
        }
        lines.add("");
        lines.add("Trend zgloszen");
        int limit = Math.min(12, dto.getZgloszeniaTrend().size());
        for (int i = 0; i < limit; i++) {
            DashboardTrendPointDTO p = dto.getZgloszeniaTrend().get(i);
            lines.add("- " + p.getDate() + ": " + p.getCount());
        }
        if (dto.getZgloszeniaTrend().size() > limit) {
            lines.add("- ...");
        }

        return buildSimplePdf(lines);
    }

    private byte[] buildSimplePdf(List<String> rawLines) {
        List<String> lines = rawLines.stream()
                .map(this::sanitizePdfText)
                .toList();

        StringBuilder content = new StringBuilder();
        content.append("BT\n");
        content.append("/F1 11 Tf\n");
        content.append("50 800 Td\n");
        for (String line : lines) {
            content.append("(")
                    .append(escapePdfText(line))
                    .append(") Tj\nT*\n");
        }
        content.append("ET\n");

        byte[] contentBytes = content.toString().getBytes(StandardCharsets.US_ASCII);

        List<String> objects = new ArrayList<>();
        objects.add("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");
        objects.add("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n");
        objects.add("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n");
        objects.add("4 0 obj\n<< /Length " + contentBytes.length + " >>\nstream\n" + content + "endstream\nendobj\n");
        objects.add("5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n");

        StringBuilder pdf = new StringBuilder();
        pdf.append("%PDF-1.4\n");

        List<Integer> offsets = new ArrayList<>();
        offsets.add(0);
        for (String obj : objects) {
            offsets.add(pdf.length());
            pdf.append(obj);
        }

        int xrefStart = pdf.length();
        pdf.append("xref\n");
        pdf.append("0 ").append(objects.size() + 1).append("\n");
        pdf.append("0000000000 65535 f \n");
        for (int i = 1; i < offsets.size(); i++) {
            pdf.append(formatPdfOffset(offsets.get(i))).append(" 00000 n \n");
        }
        pdf.append("trailer\n");
        pdf.append("<< /Size ").append(objects.size() + 1).append(" /Root 1 0 R >>\n");
        pdf.append("startxref\n");
        pdf.append(xrefStart).append("\n");
        pdf.append("%%EOF");

        return pdf.toString().getBytes(StandardCharsets.US_ASCII);
    }

    private String formatPdfOffset(int offset) {
        return String.format(java.util.Locale.ROOT, "%010d", offset);
    }

    private String sanitizePdfText(String text) {
        if (text == null) {
            return "";
        }
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c >= 32 && c <= 126) {
                out.append(c);
            } else {
                out.append('?');
            }
        }
        return out.toString();
    }

    private String escapePdfText(String text) {
        return text
                .replace("\\", "\\\\")
                .replace("(", "\\(")
                .replace(")", "\\)");
    }

    private List<DashboardTrendPointDTO> buildZgloszenieTrend(List<Zgloszenie> zgloszenia, LocalDate startInclusive, LocalDate endInclusive) {
        List<DashboardTrendPointDTO> trend = new ArrayList<>();
        for (LocalDate day = startInclusive; !day.isAfter(endInclusive); day = day.plusDays(1)) {
            final LocalDate currentDay = day;
            long count = zgloszenia.stream()
                    .filter(z -> isInDateTimeRange(resolveZgloszenieTimestamp(z), currentDay.atStartOfDay(), currentDay.plusDays(1).atStartOfDay()))
                    .count();
            DashboardTrendPointDTO point = new DashboardTrendPointDTO();
            point.setDate(currentDay);
            point.setCount(count);
            trend.add(point);
        }
        return trend;
    }

    private List<DashboardTrendPointDTO> buildRaportTrend(List<Raport> raporty, LocalDate startInclusive, LocalDate endInclusive) {
        List<DashboardTrendPointDTO> trend = new ArrayList<>();
        for (LocalDate day = startInclusive; !day.isAfter(endInclusive); day = day.plusDays(1)) {
            final LocalDate currentDay = day;
            long count = raporty.stream()
                    .map(Raport::getDataNaprawy)
                    .filter(d -> d != null && d.equals(currentDay))
                    .count();
            DashboardTrendPointDTO point = new DashboardTrendPointDTO();
            point.setDate(currentDay);
            point.setCount(count);
            trend.add(point);
        }
        return trend;
    }

    private double percentChange(long current, long previous) {
        if (previous == 0) {
            return current == 0 ? 0.0 : 100.0;
        }
        BigDecimal change = BigDecimal.valueOf(current - previous)
                .multiply(BigDecimal.valueOf(100))
                .divide(BigDecimal.valueOf(previous), 2, RoundingMode.HALF_UP);
        return change.doubleValue();
    }
}