package drimer.drimain.api.dto;

import lombok.Data;

@Data
public class MaszynaDTO {
    private Long id;
    private String nazwa;
    private DzialDTO dzial;
}