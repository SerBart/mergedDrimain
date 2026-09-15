package drimer.drimain.service;

import drimer.drimain.api.dto.PartExcelImportResultDTO;
import drimer.drimain.model.Part;
import drimer.drimain.repository.PartRepository;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest
@Transactional
class PartExcelImportServiceMergeIntegrationTest {

    @Autowired
    private PartExcelImportService service;

    @Autowired
    private PartRepository partRepository;

    @Test
    void shouldImportDatesFromExcel() throws Exception {
        MockMultipartFile file = workbookWithSingleRow("FALOWNIK", "VFD004", 2, "szt.", "KONFEKCJA", "2026-04-04", "2026-04-05");

        PartExcelImportResultDTO result = service.importFile(file);

        assertThat(result.getCreatedCount()).isEqualTo(1);
        List<Part> parts = partRepository.findAll();
        assertThat(parts).hasSize(1);
        assertThat(parts.get(0).getDataZakupu()).isEqualTo(LocalDate.of(2026, 4, 4));
        assertThat(parts.get(0).getDataRealizacji()).isEqualTo(LocalDate.of(2026, 4, 5));
    }

    @Test
    void shouldMergeByNameAndCategoryWhenOpisChanged() throws Exception {
        service.importFile(workbookWithSingleRow("LOZYSKO 608", "STARY OPIS", 1, "szt.", "MONTAZ", "2026-01-02", "2026-01-03"));

        PartExcelImportResultDTO merged = service.importFile(
                workbookWithSingleRow("LOZYSKO 608", "NOWY OPIS", 7, "szt.", "MONTAZ", "2026-02-02", "2026-02-03"),
                PartExcelImportService.ImportMode.MERGE
        );

        assertThat(merged.getCreatedCount()).isEqualTo(0);
        assertThat(merged.getUpdatedCount()).isEqualTo(1);

        List<Part> parts = partRepository.findAll();
        assertThat(parts).hasSize(1);
        assertThat(parts.get(0).getOpis()).isEqualTo("NOWY OPIS");
        assertThat(parts.get(0).getIlosc()).isEqualTo(7);
    }

    private MockMultipartFile workbookWithSingleRow(String nazwa,
                                                    String opis,
                                                    int ilosc,
                                                    String jednostka,
                                                    String dzial,
                                                    String dataZgloszenia,
                                                    String dataRealizacji) throws IOException {
        try (XSSFWorkbook workbook = new XSSFWorkbook(); ByteArrayOutputStream bos = new ByteArrayOutputStream()) {
            var sheet = workbook.createSheet("Import");
            Row header = sheet.createRow(0);
            header.createCell(0).setCellValue("PRIORYTET");
            header.createCell(1).setCellValue("NAZWA");
            header.createCell(2).setCellValue("OPIS");
            header.createCell(3).setCellValue("ILOŚĆ");
            header.createCell(4).setCellValue("JEDNOSTA");
            header.createCell(5).setCellValue("DATA ZGŁOSZENIA");
            header.createCell(6).setCellValue("DATA REALIZACJI");
            header.createCell(7).setCellValue("STATUS");
            header.createCell(8).setCellValue("OSOBA");
            header.createCell(9).setCellValue("DZIAŁ");

            Row data = sheet.createRow(1);
            data.createCell(0).setCellValue(1);
            data.createCell(1).setCellValue(nazwa);
            data.createCell(2).setCellValue(opis);
            data.createCell(3).setCellValue(ilosc);
            data.createCell(4).setCellValue(jednostka);
            data.createCell(5).setCellValue(dataZgloszenia);
            data.createCell(6).setCellValue(dataRealizacji);
            data.createCell(7).setCellValue("Zrealizowane");
            data.createCell(8).setCellValue("Jan Kowalski");
            data.createCell(9).setCellValue(dzial);

            workbook.write(bos);
            return new MockMultipartFile(
                    "file",
                    "parts.xlsx",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    bos.toByteArray()
            );
        }
    }
}

