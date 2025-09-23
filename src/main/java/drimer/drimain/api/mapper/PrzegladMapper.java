package drimer.drimain.api.mapper;

import drimer.drimain.api.dto.PrzegladCreateRequest;
import drimer.drimain.api.dto.PrzegladDTO;
import drimer.drimain.api.dto.PrzegladUpdateRequest;
import drimer.drimain.api.dto.SimpleMaszynaDTO;
import drimer.drimain.api.dto.SimpleOsobaDTO;
import drimer.drimain.model.Maszyna;
import drimer.drimain.model.Osoba;
import drimer.drimain.model.Przeglad;
import drimer.drimain.model.enums.StatusPrzegladu;
import drimer.drimain.model.enums.TypPrzegladu;
import drimer.drimain.repository.MaszynaRepository;
import drimer.drimain.repository.OsobaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class PrzegladMapper {

    private final MaszynaRepository maszynaRepository;
    private final OsobaRepository osobaRepository;

    public PrzegladDTO toDto(Przeglad p) {
        PrzegladDTO dto = new PrzegladDTO();
        dto.setId(p.getId());
        dto.setData(p.getData());
        dto.setTyp(p.getTyp() != null ? p.getTyp().name() : null);
        dto.setOpis(p.getOpis());
        if (p.getMaszyna() != null) {
            SimpleMaszynaDTO m = new SimpleMaszynaDTO();
            m.setId(p.getMaszyna().getId());
            m.setNazwa(p.getMaszyna().getNazwa());
            dto.setMaszyna(m);
        }
        if (p.getOsoba() != null) {
            SimpleOsobaDTO o = new SimpleOsobaDTO();
            o.setId(p.getOsoba().getId());
            o.setImieNazwisko(p.getOsoba().getImieNazwisko());
            dto.setOsoba(o);
        }
        dto.setStatus(p.getStatus() != null ? p.getStatus().name() : null);
        return dto;
    }

    public void updateEntity(Przeglad p, PrzegladUpdateRequest req) {
        if (req.getData() != null) p.setData(req.getData());
        if (req.getTyp() != null) {
            try { p.setTyp(TypPrzegladu.valueOf(req.getTyp())); } catch (Exception ignored) {}
        }
        if (req.getOpis() != null) p.setOpis(req.getOpis());
        if (req.getMaszynaId() != null) {
            Maszyna m = maszynaRepository.findById(req.getMaszynaId())
                    .orElseThrow(() -> new IllegalArgumentException("Maszyna not found"));
            p.setMaszyna(m);
        }
        if (req.getOsobaId() != null) {
            Osoba o = osobaRepository.findById(req.getOsobaId())
                    .orElseThrow(() -> new IllegalArgumentException("Osoba not found"));
            p.setOsoba(o);
        }
        if (req.getStatus() != null) {
            try { p.setStatus(StatusPrzegladu.valueOf(req.getStatus())); } catch (Exception ignored) {}
        }
    }

    public void applyCreateDefaults(Przeglad p, PrzegladCreateRequest req) {
        if (req.getTyp() != null) {
            try { p.setTyp(TypPrzegladu.valueOf(req.getTyp())); } catch (Exception ignored) {}
        }
        if (req.getStatus() != null) {
            try { p.setStatus(StatusPrzegladu.valueOf(req.getStatus())); } catch (Exception ignored) {}
        }
    }
}