package drimer.drimain.service;

import drimer.drimain.api.dto.*;
import drimer.drimain.model.*;
import drimer.drimain.repository.*;
import drimer.drimain.config.AttachmentStorageConfig;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class InstructionService {

    private final InstructionRepository instructionRepository;
    private final InstructionPartRepository instructionPartRepository;
    private final InstructionAttachmentRepository instructionAttachmentRepository;
    private final MaszynaRepository maszynaRepository;
    private final PartRepository partRepository;
    private final AttachmentStorageConfig storageConfig;

    public InstructionDTO create(InstructionCreateRequest req, String createdBy) {
        Maszyna m = maszynaRepository.findById(req.getMaszynaId())
                .orElseThrow(() -> new IllegalArgumentException("Maszyna not found: " + req.getMaszynaId()));

        Instruction ins = new Instruction();
        ins.setTitle(req.getTitle());
        ins.setDescription(req.getDescription());
        ins.setMaszyna(m);
        ins.setCreatedBy(createdBy);

        if (req.getParts() != null) {
            List<InstructionPart> parts = new ArrayList<>();
            for (InstructionCreateRequest.InstructionPartRef pr : req.getParts()) {
                Part p = partRepository.findById(pr.getPartId())
                        .orElseThrow(() -> new IllegalArgumentException("Part not found: " + pr.getPartId()));
                InstructionPart ip = new InstructionPart();
                ip.setInstruction(ins);
                ip.setPart(p);
                ip.setIlosc(pr.getIlosc());
                parts.add(ip);
            }
            ins.setParts(parts);
        }
        instructionRepository.save(ins);
        return toDto(ins);
    }

    @Transactional(readOnly = true)
    public List<InstructionDTO> list(Long maszynaId) {
        List<Instruction> list = (maszynaId == null)
                ? instructionRepository.findAllByOrderByCreatedAtDesc()
                : instructionRepository.findByMaszyna_IdOrderByCreatedAtDesc(maszynaId);
        return list.stream().map(this::toDtoBasic).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public InstructionDTO get(Long id) {
        Instruction ins = instructionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Instruction not found: " + id));
        InstructionDTO dto = toDto(ins);
        dto.attachments = instructionAttachmentRepository
                .findByInstruction_IdOrderByCreatedAtDesc(id)
                .stream().map(this::toAttachmentDto).collect(Collectors.toList());
        return dto;
    }

    public List<InstructionAttachmentDTO> upload(Long instructionId, List<MultipartFile> files, String createdBy) {
        Instruction ins = instructionRepository.findById(instructionId)
                .orElseThrow(() -> new IllegalArgumentException("Instruction not found: " + instructionId));

        Path storageDir = Paths.get(storageConfig.getBasePath());
        try { Files.createDirectories(storageDir); } catch (IOException e) { throw new RuntimeException(e); }

        List<InstructionAttachment> saved = new ArrayList<>();
        for (MultipartFile file : files) {
            validateFile(file);
            String original = file.getOriginalFilename();
            String ext = getFileExtension(original);
            String stored = UUID.randomUUID() + ext;
            Path fp = storageDir.resolve(stored);
            try {
                Files.copy(file.getInputStream(), fp, StandardCopyOption.REPLACE_EXISTING);
                InstructionAttachment ia = new InstructionAttachment();
                ia.setInstruction(ins);
                ia.setOriginalFilename(original);
                ia.setStoredFilename(stored);
                ia.setContentType(file.getContentType());
                ia.setFileSize(file.getSize());
                ia.setChecksum(calcChecksumSafe(file));
                ia.setCreatedBy(createdBy);
                saved.add(instructionAttachmentRepository.save(ia));
            } catch (IOException ex) {
                throw new RuntimeException("Failed to store file: " + original, ex);
            }
        }
        return saved.stream().map(this::toAttachmentDto).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<InstructionAttachmentDTO> listAttachments(Long instructionId) {
        return instructionAttachmentRepository.findByInstruction_IdOrderByCreatedAtDesc(instructionId)
                .stream().map(this::toAttachmentDto).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public Resource download(Long attachmentId) {
        InstructionAttachment a = instructionAttachmentRepository.findById(attachmentId)
                .orElseThrow(() -> new IllegalArgumentException("Attachment not found: " + attachmentId));
        Path fp = Paths.get(storageConfig.getBasePath(), a.getStoredFilename());
        if (!Files.exists(fp)) throw new IllegalArgumentException("File missing: " + a.getStoredFilename());
        return new FileSystemResource(fp);
    }

    @Transactional(readOnly = true)
    public InstructionAttachmentDTO getAttachmentInfo(Long attachmentId) {
        InstructionAttachment a = instructionAttachmentRepository.findById(attachmentId)
                .orElseThrow(() -> new IllegalArgumentException("Attachment not found: " + attachmentId));
        return toAttachmentDto(a);
    }

    public void delete(Long id) {
        Instruction ins = instructionRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Instruction not found: " + id));
        // delete attachments files and rows
        List<InstructionAttachment> attachments = instructionAttachmentRepository
                .findByInstruction_IdOrderByCreatedAtDesc(id);
        Path storageDir = Paths.get(storageConfig.getBasePath());
        for (InstructionAttachment a : attachments) {
            try {
                if (a.getStoredFilename() != null) {
                    Path fp = storageDir.resolve(a.getStoredFilename());
                    try { Files.deleteIfExists(fp); } catch (Exception ignored) {}
                }
            } catch (Exception ignored) {}
        }
        instructionAttachmentRepository.deleteAll(attachments);
        // delete instruction (parts are removed via cascade)
        instructionRepository.delete(ins);
    }

    private void validateFile(MultipartFile file) {
        if (file.isEmpty()) throw new IllegalArgumentException("File is empty");
        if (file.getSize() > storageConfig.getMaxFileSizeBytes())
            throw new IllegalArgumentException("File too large: " + file.getSize());
        String ct = file.getContentType();
        if (ct == null || !storageConfig.getAllowedContentTypes().contains(ct))
            throw new IllegalArgumentException("File type not allowed: " + ct);
    }

    private String getFileExtension(String filename) {
        if (filename == null || filename.isEmpty()) return "";
        int idx = filename.lastIndexOf('.');
        return idx > 0 ? filename.substring(idx) : "";
    }

    private String calcChecksumSafe(MultipartFile file) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(file.getBytes());
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (NoSuchAlgorithmException | IOException e) {
            return null;
        }
    }

    private InstructionDTO toDtoBasic(Instruction e) {
        InstructionDTO dto = new InstructionDTO();
        dto.id = e.getId();
        dto.title = e.getTitle();
        dto.description = e.getDescription();
        dto.maszynaId = e.getMaszyna() != null ? e.getMaszyna().getId() : null;
        dto.maszynaNazwa = e.getMaszyna() != null ? e.getMaszyna().getNazwa() : null;
        dto.createdAt = e.getCreatedAt();
        dto.createdBy = e.getCreatedBy();
        return dto;
    }

    private InstructionDTO toDto(Instruction e) {
        InstructionDTO dto = toDtoBasic(e);
        dto.parts = e.getParts() == null ? List.of() : e.getParts().stream().map(ip -> {
            InstructionPartDTO p = new InstructionPartDTO();
            p.partId = ip.getPart().getId();
            p.partNazwa = ip.getPart().getNazwa();
            p.ilosc = ip.getIlosc();
            return p;
        }).collect(Collectors.toList());
        return dto;
    }

    private InstructionAttachmentDTO toAttachmentDto(InstructionAttachment a) {
        InstructionAttachmentDTO dto = new InstructionAttachmentDTO();
        dto.id = a.getId();
        dto.originalFilename = a.getOriginalFilename();
        dto.contentType = a.getContentType();
        dto.fileSize = a.getFileSize();
        dto.createdAt = a.getCreatedAt();
        dto.createdBy = a.getCreatedBy();
        return dto;
    }
}
