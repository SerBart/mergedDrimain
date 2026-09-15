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
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@Transactional
class PartExcelImportServiceIntegrationTest {

    @Autowired
    private PartExcelImportService service;

    @Autowired
    private PartRepository partRepository;

    @Test
    void shouldCreateAndThenUpdatePartByNaturalKey() throws Exception {
        MockMultipartFile first = workbookWithSingleRow("FALOWNIK", "VFD004", 2, "szt.", "KONFEKCJA");
        PartExcelImportResultDTO firstResult = service.importFile(first);

        assertThat(firstResult.getImportedCount()).isEqualTo(1);
        assertThat(firstResult.getCreatedCount()).isEqualTo(1);
        assertThat(firstResult.getUpdatedCount()).isEqualTo(0);
        assertThat(firstResult.getSkippedCount()).isEqualTo(0);

        List<Part> afterFirst = partRepository.findAll();
        assertThat(afterFirst).hasSize(1);
        Part created = afterFirst.get(0);
        assertThat(created.getNazwa()).isEqualTo("FALOWNIK");
        assertThat(created.getOpis()).isEqualTo("VFD004");
        assertThat(created.getIlosc()).isEqualTo(2);
        assertThat(created.getMaszyna()).isNull();

        MockMultipartFile second = workbookWithSingleRow("FALOWNIK", "VFD004", 9, "szt.", "KONFEKCJA");
        PartExcelImportResultDTO secondResult = service.importFile(second);

        assertThat(secondResult.getImportedCount()).isEqualTo(1);
        assertThat(secondResult.getCreatedCount()).isEqualTo(0);
        assertThat(secondResult.getUpdatedCount()).isEqualTo(1);

        List<Part> afterSecond = partRepository.findAll();
        assertThat(afterSecond).hasSize(1);
        assertThat(afterSecond.get(0).getIlosc()).isEqualTo(9);
    }

    @Test
    void shouldFailWhenRequiredHeaderIsMissing() throws IOException {
        try (XSSFWorkbook workbook = new XSSFWorkbook(); ByteArrayOutputStream bos = new ByteArrayOutputStream()) {
            var sheet = workbook.createSheet("Import");
            Row header = sheet.createRow(0);
            header.createCell(0).setCellValue("NAZWA");
            header.createCell(1).setCellValue("OPIS");
            workbook.write(bos);

            MockMultipartFile broken = new MockMultipartFile(
                    "file",
                    "broken.xlsx",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    bos.toByteArray()
            );

            assertThatThrownBy(() -> service.importFile(broken))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("Brak wymaganych kolumn");
        }
    }

    private MockMultipartFile workbookWithSingleRow(String nazwa, String opis, int ilosc, String jednostka, String dzial) throws IOException {
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
            data.createCell(5).setCellValue("4 kwi");
            data.createCell(6).setCellValue("5 kwi");
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

