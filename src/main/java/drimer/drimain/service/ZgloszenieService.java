package drimer.drimain.service;

import drimer.drimain.api.dto.ZgloszenieCreateRequest;
import drimer.drimain.api.dto.ZgloszenieUpdateRequest;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.model.enums.ZgloszenieStatus;
import drimer.drimain.repository.ZgloszenieRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ZgloszenieService {

    private final ZgloszenieRepository repo;

    public Zgloszenie create(ZgloszenieCreateRequest req) {
        Zgloszenie z = new Zgloszenie();

        z.setTyp(req.getTyp());
        z.setImie(req.getImie());
        z.setNazwisko(req.getNazwisko());
        z.setStatus(ZgloszenieStatus.valueOf(req.getStatus()));
        z.setOpis(req.getOpis());
        z.setDataGodzina(LocalDateTime.now());
        // TODO: photoBase64 -> z.setPhoto(Base64.getDecoder().decode(req.getPhotoBase64()))
        return repo.save(z);
    }

    public Zgloszenie update(Long id, ZgloszenieUpdateRequest req) {
        Zgloszenie z = repo.findById(id).orElseThrow(() -> new IllegalArgumentException("Not found"));
        if (req.getTyp() != null) z.setTyp(req.getTyp());
        if (req.getStatus() != null) z.setStatus(ZgloszenieStatus.valueOf(req.getStatus()));
        if (req.getOpis() != null) z.setOpis(req.getOpis());
        return repo.save(z);
    }

    public Zgloszenie get(Long id) {
        return repo.findById(id).orElseThrow(() -> new IllegalArgumentException("Not found"));
    }

    public List<Zgloszenie> all() { return repo.findAll(); }

    public void delete(Long id) { repo.deleteById(id); }
}