package drimer.drimain.service;

import drimer.drimain.api.dto.PartExcelImportResultDTO;
import drimer.drimain.model.Part;
import drimer.drimain.repository.PartRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.DataFormatter;
import org.apache.poi.ss.usermodel.DateUtil;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.ss.usermodel.WorkbookFactory;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

@Service
@RequiredArgsConstructor
public class PartExcelImportService {

    public enum ImportMode {
        UPSERT,
        MERGE
    }

    private static final String COL_PRIORYTET = "PRIORYTET";
    private static final String COL_NAZWA = "NAZWA";
    private static final String COL_OPIS = "OPIS";
    private static final String COL_ILOSC = "ILOSC";
    private static final String COL_JEDNOSTKA = "JEDNOSTKA";
    private static final String COL_DATA_ZGLOSZENIA = "DATAZGLOSZENIA";
    private static final String COL_DATA_REALIZACJI = "DATAREALIZACJI";
    private static final String COL_STATUS = "STATUS";
    private static final String COL_OSOBA = "OSOBA";
    private static final String COL_DZIAL = "DZIAL";
    private static final List<DateTimeFormatter> DATE_FORMATTERS = List.of(
            DateTimeFormatter.ISO_LOCAL_DATE,
            DateTimeFormatter.ofPattern("d.M.uuuu"),
            DateTimeFormatter.ofPattern("d-M-uuuu"),
            DateTimeFormatter.ofPattern("d/M/uuuu")
    );

    private final PartRepository partRepository;

    public byte[] exportFile(List<Part> parts) {
        try (Workbook workbook = new XSSFWorkbook(); ByteArrayOutputStream bos = new ByteArrayOutputStream()) {
            Sheet sheet = workbook.createSheet("Czesci");

            Row header = sheet.createRow(0);
            String[] headers = {
                    "PRIORYTET",
                    "NAZWA",
                    "OPIS",
                    "ILOŚĆ",
                    "JEDNOSTA",
                    "DATA ZGŁOSZENIA",
                    "DATA REALIZACJI",
                    "STATUS",
                    "OSOBA",
                    "DZIAŁ"
            };
            for (int i = 0; i < headers.length; i++) {
                header.createCell(i).setCellValue(headers[i]);
            }

            int rowIndex = 1;
            for (Part part : parts) {
                Row row = sheet.createRow(rowIndex++);
                row.createCell(0).setCellValue("");
                row.createCell(1).setCellValue(safe(part.getNazwa()));
                row.createCell(2).setCellValue(safe(part.getOpis()));
                row.createCell(3).setCellValue(part.getIlosc() == null ? "" : String.valueOf(part.getIlosc()));
                row.createCell(4).setCellValue(safe(part.getJednostka()));
                row.createCell(5).setCellValue("");
                row.createCell(6).setCellValue("");
                row.createCell(7).setCellValue("");
                row.createCell(8).setCellValue("");
                row.createCell(9).setCellValue(safe(part.getKategoria()));
            }

            for (int i = 0; i < headers.length; i++) {
                sheet.autoSizeColumn(i);
            }
            sheet.createFreezePane(0, 1);

            workbook.write(bos);
            return bos.toByteArray();
        } catch (IOException e) {
            throw new IllegalArgumentException("Nie udalo sie wygenerowac pliku Excel.");
        }
    }

    @Transactional
    public PartExcelImportResultDTO importFile(MultipartFile file) {
        return importFile(file, ImportMode.UPSERT);
    }

    @Transactional
    public PartExcelImportResultDTO importFile(MultipartFile file, ImportMode mode) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Plik jest pusty.");
        }

        ImportMode effectiveMode = mode == null ? ImportMode.UPSERT : mode;

        try (InputStream inputStream = file.getInputStream(); Workbook workbook = WorkbookFactory.create(inputStream)) {
            Sheet sheet = workbook.getNumberOfSheets() > 0 ? workbook.getSheetAt(0) : null;
            if (sheet == null) {
                throw new IllegalArgumentException("Brak arkusza w pliku Excel.");
            }

            Iterator<Row> iterator = sheet.iterator();
            if (!iterator.hasNext()) {
                throw new IllegalArgumentException("Brak naglowka w pliku Excel.");
            }

            Row headerRow = iterator.next();
            Map<String, Integer> columnIndex = buildHeaderIndex(headerRow);
            validateHeader(columnIndex);

            int imported = 0;
            int created = 0;
            int updated = 0;
            int skipped = 0;
            List<String> warnings = new ArrayList<>();

            DataFormatter formatter = new DataFormatter(Locale.ROOT);

            while (iterator.hasNext()) {
                Row row = iterator.next();
                int rowNum = row.getRowNum() + 1;

                String nazwa = clean(getString(row, columnIndex.get(COL_NAZWA), formatter));
                String opis = clean(getString(row, columnIndex.get(COL_OPIS), formatter));
                Integer ilosc = getInteger(row, columnIndex.get(COL_ILOSC), formatter);
                String jednostka = clean(getString(row, columnIndex.get(COL_JEDNOSTKA), formatter));
                String dzial = clean(getString(row, columnIndex.get(COL_DZIAL), formatter));
                LocalDate dataZakupu = getDate(row, columnIndex.get(COL_DATA_ZGLOSZENIA), formatter);
                LocalDate dataRealizacji = getDate(row, columnIndex.get(COL_DATA_REALIZACJI), formatter);

                if (isBlank(nazwa) && isBlank(opis) && ilosc == null && isBlank(jednostka) && isBlank(dzial)) {
                    skipped++;
                    continue;
                }

                if (isBlank(nazwa)) {
                    skipped++;
                    warnings.add("Wiersz " + rowNum + ": pominieto - brak wartości w kolumnie NAZWA.");
                    continue;
                }

                if (ilosc == null || ilosc < 0) {
                    ilosc = 0;
                    warnings.add("Wiersz " + rowNum + ": niepoprawna ILOSC, ustawiono 0.");
                }

                String kategoria = isBlank(dzial) ? null : limit(dzial, 255);
                String finalOpis = isBlank(opis) ? null : limit(opis, 2000);

                Optional<Part> existing = findExistingPart(effectiveMode, nazwa, finalOpis, kategoria);
                Part part = existing.orElseGet(Part::new);

                if (part.getId() == null) {
                    part.setKod(generateImportCode(nazwa, finalOpis, kategoria));
                    part.setMinIlosc(0);
                    created++;
                } else {
                    updated++;
                }

                part.setNazwa(limit(nazwa, 255));
                part.setOpis(finalOpis);
                part.setKategoria(kategoria);
                part.setIlosc(ilosc);
                part.setJednostka(isBlank(jednostka) ? "szt." : limit(jednostka, 50));
                part.setDataZakupu(dataZakupu);
                part.setDataRealizacji(dataRealizacji);

                // W aktualnym imporcie kolumna maszyna ma pozostac pusta.
                part.setMaszyna(null);

                partRepository.save(part);
                imported++;
            }

            return new PartExcelImportResultDTO(imported, created, updated, skipped, warnings);
        } catch (IOException e) {
            throw new IllegalArgumentException("Nie udalo sie odczytac pliku Excel.");
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (RuntimeException e) {
            throw new IllegalArgumentException("Niepoprawny format pliku Excel.");
        }
    }

    private Optional<Part> findExistingPart(ImportMode mode, String nazwa, String opis, String kategoria) {
        Optional<Part> naturalKeyMatch = partRepository.findByNaturalKey(nazwa, opis, kategoria);
        if (naturalKeyMatch.isPresent() || mode != ImportMode.MERGE) {
            return naturalKeyMatch;
        }
        return partRepository.findAllByMergeKey(nazwa, kategoria).stream().findFirst();
    }

    private void validateHeader(Map<String, Integer> headerIndex) {
        List<String> required = List.of(
                COL_PRIORYTET,
                COL_NAZWA,
                COL_OPIS,
                COL_ILOSC,
                COL_JEDNOSTKA,
                COL_DATA_ZGLOSZENIA,
                COL_DATA_REALIZACJI,
                COL_STATUS,
                COL_OSOBA,
                COL_DZIAL
        );

        List<String> missing = required.stream()
                .filter(h -> !headerIndex.containsKey(h))
                .toList();

        if (!missing.isEmpty()) {
            throw new IllegalArgumentException("Brak wymaganych kolumn: " + String.join(", ", missing));
        }
    }

    private Map<String, Integer> buildHeaderIndex(Row row) {
        Map<String, Integer> map = new HashMap<>();
        for (Cell cell : row) {
            String normalized = normalizeHeader(String.valueOf(cell));

            if ("JEDNOSTA".equals(normalized)) {
                normalized = COL_JEDNOSTKA;
            }

            if (!normalized.isBlank()) {
                map.put(normalized, cell.getColumnIndex());
            }
        }
        return map;
    }

    private String normalizeHeader(String input) {
        if (input == null) return "";
        String s = input.trim().toUpperCase(Locale.ROOT);
        s = s
                .replace('Ą', 'A').replace('Ć', 'C').replace('Ę', 'E').replace('Ł', 'L')
                .replace('Ń', 'N').replace('Ó', 'O').replace('Ś', 'S').replace('Ź', 'Z').replace('Ż', 'Z');
        return s.replaceAll("[^A-Z0-9]", "");
    }

    private String getString(Row row, Integer idx, DataFormatter formatter) {
        if (idx == null) return null;
        Cell cell = row.getCell(idx, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
        if (cell == null) return null;

        if (cell.getCellType() == CellType.FORMULA) {
            try {
                return formatter.formatCellValue(cell);
            } catch (RuntimeException ex) {
                return null;
            }
        }
        return formatter.formatCellValue(cell);
    }

    private Integer getInteger(Row row, Integer idx, DataFormatter formatter) {
        String raw = clean(getString(row, idx, formatter));
        if (isBlank(raw)) return null;
        try {
            String cleaned = raw.replace(',', '.').replaceAll("[^0-9.\\-]", "");
            if (cleaned.isBlank()) return null;
            return (int) Math.round(Double.parseDouble(cleaned));
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private LocalDate getDate(Row row, Integer idx, DataFormatter formatter) {
        if (idx == null) return null;

        Cell cell = row.getCell(idx, Row.MissingCellPolicy.RETURN_BLANK_AS_NULL);
        if (cell == null) return null;

        if (cell.getCellType() == CellType.NUMERIC && DateUtil.isCellDateFormatted(cell)) {
            try {
                return cell.getLocalDateTimeCellValue().toLocalDate();
            } catch (RuntimeException ex) {
                return null;
            }
        }

        String raw = clean(formatter.formatCellValue(cell));
        if (isBlank(raw)) return null;

        String normalized = raw.replace('/', '-').replace('.', '-');
        for (DateTimeFormatter formatterItem : DATE_FORMATTERS) {
            try {
                return LocalDate.parse(normalized, formatterItem);
            } catch (DateTimeParseException ignored) {
                // try next format
            }
        }
        try {
            return LocalDate.parse(raw);
        } catch (DateTimeParseException ignored) {
            return null;
        }
    }

    private String generateImportCode(String nazwa, String opis, String kategoria) {
        String seed = (safe(nazwa) + "|" + safe(opis) + "|" + safe(kategoria)).toUpperCase(Locale.ROOT);
        String hash = Integer.toHexString(seed.hashCode()).toUpperCase(Locale.ROOT);
        return limit("IMP-" + hash, 255);
    }

    private String safe(String value) {
        return value == null ? "" : value.trim();
    }

    private String clean(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private boolean isBlank(String s) {
        return s == null || s.trim().isEmpty();
    }

    private String limit(String value, int max) {
        if (value == null) return null;
        return value.length() <= max ? value : value.substring(0, max);
    }
}
