package drimer.drimain.api.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.List;

@Data
@AllArgsConstructor
public class PartExcelImportResultDTO {
    private int importedCount;
    private int createdCount;
    private int updatedCount;
    private int skippedCount;
    private List<String> warnings;
}

