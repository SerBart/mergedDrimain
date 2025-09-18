package drimer.drimain.api.mapper;

import drimer.drimain.api.dto.ZgloszenieDTO;
import drimer.drimain.model.Zgloszenie;

public final class ZgloszenieMapper {
    private ZgloszenieMapper() {}

    public static ZgloszenieDTO toDto(Zgloszenie z) {
        ZgloszenieDTO dto = new ZgloszenieDTO();
        dto.setId(z.getId());
        dto.setTyp(z.getTyp());
        dto.setImie(z.getImie());
        dto.setNazwisko(z.getNazwisko());
        dto.setTytul(z.getTytul());
        dto.setStatus(z.getStatus());
        dto.setPriorytet(z.getPriorytet()); // Add priority mapping
        dto.setOpis(z.getOpis());
        dto.setDataGodzina(z.getDataGodzina());
        dto.setCreatedAt(z.getCreatedAt());
        dto.setUpdatedAt(z.getUpdatedAt());
        
        // Handle relations
        if (z.getDzial() != null) {
            dto.setDzialId(z.getDzial().getId());
            dto.setDzialNazwa(z.getDzial().getNazwa());
        }
        if (z.getAutor() != null) {
            dto.setAutorId(z.getAutor().getId());
            dto.setAutorUsername(z.getAutor().getUsername());
        }
        
        return dto;
    }

    public static void updateEntity(Zgloszenie z, ZgloszenieDTO dto) {
        z.setTyp(dto.getTyp());
        z.setImie(dto.getImie());
        z.setNazwisko(dto.getNazwisko());
        z.setTytul(dto.getTytul());
        z.setStatus(dto.getStatus());
        z.setPriorytet(dto.getPriorytet()); // Add priority mapping
        z.setOpis(dto.getOpis());
        z.setDataGodzina(dto.getDataGodzina());
        // Note: createdAt/updatedAt are managed by @PrePersist/@PreUpdate
        // Note: relations should be handled in the controller/service layer
    }
}