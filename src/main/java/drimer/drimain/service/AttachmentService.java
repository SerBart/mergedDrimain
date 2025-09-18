package drimer.drimain.service;

import drimer.drimain.api.dto.AttachmentDTO;
import drimer.drimain.api.mapper.AttachmentMapper;
import drimer.drimain.config.AttachmentStorageConfig;
import drimer.drimain.events.EventType;
import drimer.drimain.events.ZgloszenieDomainEvent;
import drimer.drimain.model.Attachment;
import drimer.drimain.model.Zgloszenie;
import drimer.drimain.repository.AttachmentRepository;
import drimer.drimain.repository.ZgloszenieRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
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
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
@Slf4j
public class AttachmentService {

    private final AttachmentRepository attachmentRepository;
    private final ZgloszenieRepository zgloszenieRepository;
    private final AttachmentMapper attachmentMapper;
    private final AttachmentStorageConfig storageConfig;
    private final ApplicationEventPublisher eventPublisher;

    public List<AttachmentDTO> uploadAttachments(Long zgloszenieId, List<MultipartFile> files, String createdBy) {
        Zgloszenie zgloszenie = zgloszenieRepository.findById(zgloszenieId)
                .orElseThrow(() -> new IllegalArgumentException("Zgloszenie not found: " + zgloszenieId));

        // Ensure storage directory exists
        Path storageDir = Paths.get(storageConfig.getBasePath());
        try {
            Files.createDirectories(storageDir);
        } catch (IOException e) {
            throw new RuntimeException("Failed to create storage directory", e);
        }

        List<Attachment> savedAttachments = files.stream()
                .map(file -> uploadSingleFile(zgloszenie, file, createdBy))
                .collect(Collectors.toList());

        // Publish attachment events
        savedAttachments.forEach(attachment -> {
            eventPublisher.publishEvent(new ZgloszenieDomainEvent(
                    this,
                    EventType.ATTACHMENT_ADDED,
                    zgloszenieId,
                    null,
                    attachment.getId(),
                    null // TODO: snapshot for filtering
            ));
        });

        return savedAttachments.stream()
                .map(attachmentMapper::toDto)
                .collect(Collectors.toList());
    }

    public List<AttachmentDTO> listAttachments(Long zgloszenieId) {
        List<Attachment> attachments = attachmentRepository.findByZgloszenieIdOrderByCreatedAtDesc(zgloszenieId);
        return attachments.stream()
                .map(attachmentMapper::toDto)
                .collect(Collectors.toList());
    }

    public Resource downloadAttachment(Long attachmentId) {
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .orElseThrow(() -> new IllegalArgumentException("Attachment not found: " + attachmentId));

        Path filePath = Paths.get(storageConfig.getBasePath(), attachment.getStoredFilename());
        if (!Files.exists(filePath)) {
            throw new IllegalArgumentException("File not found on disk: " + attachment.getStoredFilename());
        }

        return new FileSystemResource(filePath);
    }

    public void deleteAttachment(Long attachmentId) {
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .orElseThrow(() -> new IllegalArgumentException("Attachment not found: " + attachmentId));

        Long zgloszenieId = attachment.getZgloszenie().getId();
        
        // Delete file from disk
        Path filePath = Paths.get(storageConfig.getBasePath(), attachment.getStoredFilename());
        try {
            Files.deleteIfExists(filePath);
        } catch (IOException e) {
            log.warn("Failed to delete file from disk: {}", filePath, e);
        }

        // Delete from database
        attachmentRepository.delete(attachment);

        // Publish attachment removed event
        eventPublisher.publishEvent(new ZgloszenieDomainEvent(
                this,
                EventType.ATTACHMENT_REMOVED,
                zgloszenieId,
                null,
                attachmentId,
                null // TODO: snapshot for filtering
        ));
    }

    public AttachmentDTO getAttachmentInfo(Long attachmentId) {
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .orElseThrow(() -> new IllegalArgumentException("Attachment not found: " + attachmentId));
        return attachmentMapper.toDto(attachment);
    }

    private Attachment uploadSingleFile(Zgloszenie zgloszenie, MultipartFile file, String createdBy) {
        validateFile(file);

        String originalFilename = file.getOriginalFilename();
        String fileExtension = getFileExtension(originalFilename);
        String storedFilename = generateStoredFilename(fileExtension);

        Path filePath = Paths.get(storageConfig.getBasePath(), storedFilename);

        try {
            // Copy file to storage
            Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);

            // Calculate checksum (optional TODO as noted in requirements)
            String checksum = null;
            try {
                checksum = calculateChecksum(file.getBytes());
            } catch (Exception e) {
                log.warn("Failed to calculate checksum for file: {}", originalFilename, e);
            }

            // Create attachment entity
            Attachment attachment = new Attachment();
            attachment.setZgloszenie(zgloszenie);
            attachment.setOriginalFilename(originalFilename);
            attachment.setStoredFilename(storedFilename);
            attachment.setContentType(file.getContentType());
            attachment.setFileSize(file.getSize());
            attachment.setChecksum(checksum);
            attachment.setCreatedBy(createdBy);

            return attachmentRepository.save(attachment);

        } catch (IOException e) {
            throw new RuntimeException("Failed to store file: " + originalFilename, e);
        }
    }

    private void validateFile(MultipartFile file) {
        if (file.isEmpty()) {
            throw new IllegalArgumentException("File is empty");
        }

        if (file.getSize() > storageConfig.getMaxFileSizeBytes()) {
            throw new IllegalArgumentException("File size exceeds maximum allowed: " + 
                    storageConfig.getMaxFileSizeBytes() + " bytes");
        }

        String contentType = file.getContentType();
        if (contentType == null || !storageConfig.getAllowedContentTypes().contains(contentType)) {
            throw new IllegalArgumentException("File type not allowed: " + contentType);
        }
    }

    private String getFileExtension(String filename) {
        if (filename == null || filename.isEmpty()) {
            return "";
        }
        int lastDotIndex = filename.lastIndexOf('.');
        return lastDotIndex > 0 ? filename.substring(lastDotIndex) : "";
    }

    private String generateStoredFilename(String extension) {
        return UUID.randomUUID().toString() + extension;
    }

    private String calculateChecksum(byte[] data) throws NoSuchAlgorithmException {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] hash = md.digest(data);
        StringBuilder sb = new StringBuilder();
        for (byte b : hash) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}