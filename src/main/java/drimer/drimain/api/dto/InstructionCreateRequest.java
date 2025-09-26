package drimer.drimain.api.dto;

import java.util.List;

public class InstructionCreateRequest {
    private String title;
    private String description;
    private Long maszynaId;
    private List<InstructionPartRef> parts;

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public Long getMaszynaId() { return maszynaId; }
    public void setMaszynaId(Long maszynaId) { this.maszynaId = maszynaId; }
    public List<InstructionPartRef> getParts() { return parts; }
    public void setParts(List<InstructionPartRef> parts) { this.parts = parts; }

    public static class InstructionPartRef {
        private Long partId; private Integer ilosc;
        public Long getPartId() { return partId; }
        public void setPartId(Long partId) { this.partId = partId; }
        public Integer getIlosc() { return ilosc; }
        public void setIlosc(Integer ilosc) { this.ilosc = ilosc; }
    }
}

