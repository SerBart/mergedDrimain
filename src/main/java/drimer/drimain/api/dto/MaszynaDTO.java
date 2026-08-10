package drimer.drimain.api.dto;

import lombok.Data;

import java.util.List;

@Data
public class MaszynaDTO {
    private Long id;
    private String nazwa;
    private DzialDTO dzial;
    private SekcjaDTO sekcja;
    private List<SekcjaDTO> sekcje;
}