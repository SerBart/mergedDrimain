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
        dto.setPriorytet(z.getPriorytet());
        dto.setOpis(z.getOpis());
        dto.setDataGodzina(z.getDataGodzina());
        dto.setCreatedAt(z.getCreatedAt());
        dto.setUpdatedAt(z.getUpdatedAt());
        dto.setAcceptedAt(z.getAcceptedAt());
        dto.setCompletedAt(z.getCompletedAt());

        // Handle relations safely (check for initialized proxies)
        try {
            if (z.getDzial() != null) {
                dto.setDzialId(z.getDzial().getId());
                dto.setDzialNazwa(z.getDzial().getNazwa());
            }
        } catch (Exception e) {
            // Lazy loading failed - dzial not fetched
        }

        try {
            if (z.getAutor() != null) {
                dto.setAutorId(z.getAutor().getId());
                dto.setAutorUsername(z.getAutor().getUsername());
            }
        } catch (Exception e) {
            // Lazy loading failed - autor not fetched
        }

        try {
            if (z.getMaszyna() != null) {
                dto.setMaszynaId(z.getMaszyna().getId());
                dto.setMaszynaNazwa(z.getMaszyna().getNazwa());
                if (z.getMaszyna().getDzial() != null) {
                    dto.setMaszynaDzialNazwa(z.getMaszyna().getDzial().getNazwa());
                }
            }
        } catch (Exception e) {
            // Lazy loading failed - maszyna not fetched
        }

        return dto;
    }

    public static void updateEntity(Zgloszenie z, ZgloszenieDTO dto) {
        z.setTyp(dto.getTyp());
        z.setImie(dto.getImie());
        z.setNazwisko(dto.getNazwisko());
        z.setTytul(dto.getTytul());
        z.setStatus(dto.getStatus());
        z.setPriorytet(dto.getPriorytet());
        z.setOpis(dto.getOpis());
        z.setDataGodzina(dto.getDataGodzina());
    }
}