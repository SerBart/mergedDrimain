package drimer.drimain.service;

import drimer.drimain.model.Zgloszenie;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Serwis do eksportu zgłoszeń do pliku Excel (.xlsx).
 */
@Service
@RequiredArgsConstructor
public class ZgloszenieExportService {

    private static final DateTimeFormatter DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    /**
     * Eksportuje listę zgłoszeń do pliku Excel.
     *
     * @param zgloszenia lista zgłoszeń do eksportu
     * @return tablica bajtów zawierająca plik Excel
     * @throws IOException w wypadku błędu podczas tworzenia pliku
     */
    public byte[] exportZgloszeniaToExcel(List<Zgloszenie> zgloszenia) throws IOException {
        try (XSSFWorkbook workbook = new XSSFWorkbook();
             ByteArrayOutputStream bos = new ByteArrayOutputStream()) {

            Sheet sheet = workbook.createSheet("Zgłoszenia");

            // Style dla nagłówka
            CellStyle headerStyle = createHeaderStyle(workbook);

            // Tworzenie wiersza nagłówka
            Row headerRow = sheet.createRow(0);
            String[] headers = {"ID", "Typ", "Imię", "Nazwisko", "Tytuł", "Status", "Priorytet", "Opis", "Data/Godzina", "Dział", "Autor", "Data Utworzenia", "Data Akceptacji", "Data Ukończenia"};

            for (int i = 0; i < headers.length; i++) {
                Cell cell = headerRow.createCell(i);
                cell.setCellValue(headers[i]);
                cell.setCellStyle(headerStyle);
            }

            // Wypełnianie danych
            int rowNum = 1;
            CellStyle dataStyle = createDataStyle(workbook);

            for (Zgloszenie z : zgloszenia) {
                Row row = sheet.createRow(rowNum++);

                row.createCell(0).setCellValue(z.getId() != null ? z.getId().toString() : "");
                row.createCell(1).setCellValue(z.getTyp() != null ? z.getTyp() : "");
                row.createCell(2).setCellValue(z.getImie() != null ? z.getImie() : "");
                row.createCell(3).setCellValue(z.getNazwisko() != null ? z.getNazwisko() : "");
                row.createCell(4).setCellValue(z.getTytul() != null ? z.getTytul() : "");
                row.createCell(5).setCellValue(z.getStatus() != null ? z.getStatus().toString() : "");
                row.createCell(6).setCellValue(z.getPriorytet() != null ? z.getPriorytet().toString() : "");
                row.createCell(7).setCellValue(z.getOpis() != null ? z.getOpis() : "");
                row.createCell(8).setCellValue(z.getDataGodzina() != null ? z.getDataGodzina().format(DATE_TIME_FORMATTER) : "");
                row.createCell(9).setCellValue(z.getDzial() != null && z.getDzial().getNazwa() != null ? z.getDzial().getNazwa() : "");
                row.createCell(10).setCellValue(z.getAutor() != null && z.getAutor().getUsername() != null ? z.getAutor().getUsername() : "");
                row.createCell(11).setCellValue(z.getCreatedAt() != null ? z.getCreatedAt().format(DATE_TIME_FORMATTER) : "");
                row.createCell(12).setCellValue(z.getAcceptedAt() != null ? z.getAcceptedAt().format(DATE_TIME_FORMATTER) : "");
                row.createCell(13).setCellValue(z.getCompletedAt() != null ? z.getCompletedAt().format(DATE_TIME_FORMATTER) : "");

                // Stosowanie stylu danych do każdej komórki
                for (int i = 0; i < headers.length; i++) {
                    row.getCell(i).setCellStyle(dataStyle);
                }
            }

            // Auto-sizing kolumn
            for (int i = 0; i < headers.length; i++) {
                sheet.autoSizeColumn(i);
            }

            // Zamrażanie pierwszego wiersza
            sheet.createFreezePane(0, 1);

            workbook.write(bos);
            return bos.toByteArray();
        }
    }

    /**
     * Tworzy styl dla komórek nagłówka.
     */
    private CellStyle createHeaderStyle(Workbook workbook) {
        CellStyle style = workbook.createCellStyle();
        Font font = workbook.createFont();
        font.setBold(true);
        font.setColor(IndexedColors.WHITE.getIndex());
        font.setFontHeightInPoints((short) 12);
        style.setFont(font);
        style.setFillForegroundColor(IndexedColors.DARK_BLUE.getIndex());
        style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        style.setAlignment(HorizontalAlignment.CENTER);
        style.setVerticalAlignment(VerticalAlignment.CENTER);
        style.setBorderBottom(BorderStyle.THIN);
        style.setBorderTop(BorderStyle.THIN);
        style.setBorderLeft(BorderStyle.THIN);
        style.setBorderRight(BorderStyle.THIN);
        return style;
    }

    /**
     * Tworzy styl dla komórek z danymi.
     */
    private CellStyle createDataStyle(Workbook workbook) {
        CellStyle style = workbook.createCellStyle();
        style.setAlignment(HorizontalAlignment.LEFT);
        style.setVerticalAlignment(VerticalAlignment.TOP);
        style.setWrapText(true);
        style.setBorderBottom(BorderStyle.THIN);
        style.setBorderTop(BorderStyle.THIN);
        style.setBorderLeft(BorderStyle.THIN);
        style.setBorderRight(BorderStyle.THIN);
        return style;
    }
}
