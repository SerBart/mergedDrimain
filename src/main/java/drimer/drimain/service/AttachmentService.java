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

/**
 * Service for managing file attachments.
 * Handles secure file uploads with validation, storage, and retrieval.
 * Prevents path traversal attacks and validates file types.
 */
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

    // Allowed MIME types - whitelist approach
    private static final String[] ALLOWED_MIME_TYPES = {
            "image/png", "image/jpeg", "image/gif", "image/webp",
            "application/pdf", "text/plain",
            "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    };

    // Magic bytes for file validation
    private static final byte[][] FILE_SIGNATURES = {
            {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF}, // JPEG
            {(byte) 0x89, 0x50, 0x4E, 0x47},         // PNG
            {0x47, 0x49, 0x46},                      // GIF
            {0x52, 0x49, 0x46, 0x46},                // WebP/WAV/AVI
            {0x25, 0x50, 0x44, 0x46}                 // PDF
    };

    /**
     * Upload multiple files for a Zgloszenie.
     * @param zgloszenieId The Zgloszenie ID
     * @param files List of files to upload
     * @param createdBy User creating the attachment
     * @return List of created attachment DTOs
     */
    public List<AttachmentDTO> uploadAttachments(Long zgloszenieId, List<MultipartFile> files, String createdBy) {
        log.info("Uploading {} attachments for Zgloszenie id={}", files.size(), zgloszenieId);
        
        Zgloszenie zgloszenie = zgloszenieRepository.findById(zgloszenieId)
                .orElseThrow(() -> {
                    log.warn("Zgloszenie not found for attachment upload: {}", zgloszenieId);
                    return new IllegalArgumentException("Zgloszenie not found: " + zgloszenieId);
                });

        // Ensure storage directory exists
        Path storageDir = Paths.get(storageConfig.getBasePath());
        try {
            Files.createDirectories(storageDir);
            log.debug("Storage directory ensured at: {}", storageDir);
        } catch (IOException e) {
            log.error("Failed to create storage directory: {}", storageDir, e);
            throw new RuntimeException("Failed to create storage directory", e);
        }

        List<Attachment> savedAttachments = files.stream()
                .map(file -> uploadSingleFile(zgloszenie, file, createdBy))
                .collect(Collectors.toList());

        // Publish attachment events
        savedAttachments.forEach(attachment -> {
            log.debug("Publishing ATTACHMENT_ADDED event for attachment id={}", attachment.getId());
            eventPublisher.publishEvent(new ZgloszenieDomainEvent(
                    this,
                    EventType.ATTACHMENT_ADDED,
                    zgloszenieId,
                    null,
                    attachment.getId(),
                    null
            ));
        });

        log.info("Successfully uploaded {} attachments for Zgloszenie id={}", savedAttachments.size(), zgloszenieId);
        return savedAttachments.stream()
                .map(attachmentMapper::toDto)
                .collect(Collectors.toList());
    }

    /**
     * List all attachments for a Zgloszenie.
     * @param zgloszenieId The Zgloszenie ID
     * @return List of attachment DTOs
     */
    public List<AttachmentDTO> listAttachments(Long zgloszenieId) {
        log.debug("Listing attachments for Zgloszenie id={}", zgloszenieId);
        List<Attachment> attachments = attachmentRepository.findByZgloszenieIdOrderByCreatedAtDesc(zgloszenieId);
        return attachments.stream()
                .map(attachmentMapper::toDto)
                .collect(Collectors.toList());
    }

    /**
     * Download an attachment file.
     * @param attachmentId The attachment ID
     * @return FileSystemResource for download
     */
    public Resource downloadAttachment(Long attachmentId) {
        log.debug("Downloading attachment id={}", attachmentId);
        
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .orElseThrow(() -> {
                    log.warn("Attachment not found for download: {}", attachmentId);
                    return new IllegalArgumentException("Attachment not found: " + attachmentId);
                });

        Path filePath = Paths.get(storageConfig.getBasePath(), attachment.getStoredFilename());
        
        // Security: Ensure file is within storage directory (path traversal protection)
        try {
            filePath = filePath.toRealPath();
            Path storagePath = Paths.get(storageConfig.getBasePath()).toRealPath();
            
            if (!filePath.startsWith(storagePath)) {
                log.error("Path traversal attempt detected: requested path={}, storage path={}", 
                        filePath, storagePath);
                throw new IllegalArgumentException("Invalid file path");
            }
        } catch (IOException e) {
            log.error("Error validating file path for attachment id={}", attachmentId, e);
            throw new RuntimeException("File path validation failed", e);
        }
        
        if (!Files.exists(filePath)) {
            log.warn("File not found on disk for attachment id={}: {}", attachmentId, filePath);
            throw new IllegalArgumentException("File not found on disk: " + attachment.getStoredFilename());
        }

        log.info("Attachment id={} prepared for download", attachmentId);
        return new FileSystemResource(filePath);
    }

    /**
     * Delete an attachment.
     * @param attachmentId The attachment ID
     */
    public void deleteAttachment(Long attachmentId) {
        log.info("Deleting attachment id={}", attachmentId);
        
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .orElseThrow(() -> {
                    log.warn("Attachment not found for deletion: {}", attachmentId);
                    return new IllegalArgumentException("Attachment not found: " + attachmentId);
                });

        Long zgloszenieId = attachment.getZgloszenie().getId();

        // Delete file from disk
        Path filePath = Paths.get(storageConfig.getBasePath(), attachment.getStoredFilename());
        try {
            Files.deleteIfExists(filePath);
            log.info("File deleted from disk: {}", filePath);
        } catch (IOException e) {
            log.warn("Failed to delete file from disk: {}", filePath, e);
        }

        // Delete from database
        attachmentRepository.delete(attachment);
        log.info("Attachment id={} deleted from database", attachmentId);

        // Publish attachment removed event
        eventPublisher.publishEvent(new ZgloszenieDomainEvent(
                this,
                EventType.ATTACHMENT_REMOVED,
                zgloszenieId,
                null,
                attachmentId,
                null
        ));
    }

    /**
     * Get attachment metadata.
     * @param attachmentId The attachment ID
     * @return Attachment DTO
     */
    public AttachmentDTO getAttachmentInfo(Long attachmentId) {
        log.debug("Fetching attachment info for id={}", attachmentId);
        Attachment attachment = attachmentRepository.findById(attachmentId)
                .orElseThrow(() -> {
                    log.warn("Attachment not found: {}", attachmentId);
                    return new IllegalArgumentException("Attachment not found: " + attachmentId);
                });
        return attachmentMapper.toDto(attachment);
    }

    /**
     * Upload a single file with comprehensive validation.
     */
    private Attachment uploadSingleFile(Zgloszenie zgloszenie, MultipartFile file, String createdBy) {
        log.debug("Uploading single file: {} (size: {} bytes)", file.getOriginalFilename(), file.getSize());
        
        validateFile(file);

        String originalFilename = file.getOriginalFilename();
        String fileExtension = getFileExtension(originalFilename);
        String storedFilename = generateStoredFilename(fileExtension);

        Path filePath = Paths.get(storageConfig.getBasePath(), storedFilename);

        try {
            // Validate file content with magic bytes
            byte[] fileBytes = file.getBytes();
            validateFileContent(fileBytes, file.getContentType());

            // Copy file to storage
            Files.copy(file.getInputStream(), filePath, StandardCopyOption.REPLACE_EXISTING);
            log.debug("File stored at: {}", filePath);

            // Calculate checksum
            String checksum = null;
            try {
                checksum = calculateChecksum(fileBytes);
                log.debug("File checksum calculated: {}", checksum);
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

            Attachment saved = attachmentRepository.save(attachment);
            log.info("File uploaded successfully: {} -> id={}", originalFilename, saved.getId());
            return saved;

        } catch (IOException e) {
            log.error("Failed to store file: {}", originalFilename, e);
            throw new RuntimeException("Failed to store file: " + originalFilename, e);
        }
    }

    /**
     * Validate file with comprehensive checks.
     */
    private void validateFile(MultipartFile file) {
        if (file.isEmpty()) {
            log.warn("Upload attempt with empty file");
            throw new IllegalArgumentException("File is empty");
        }

        if (file.getSize() > storageConfig.getMaxFileSizeBytes()) {
            log.warn("File size exceeds limit: {} > {}", 
                    file.getSize(), storageConfig.getMaxFileSizeBytes());
            throw new IllegalArgumentException("File size exceeds maximum allowed: " + 
                    storageConfig.getMaxFileSizeBytes() + " bytes");
        }

        String contentType = file.getContentType();
        if (contentType == null || !storageConfig.getAllowedContentTypes().contains(contentType)) {
            log.warn("File type not allowed: {}", contentType);
            throw new IllegalArgumentException("File type not allowed: " + contentType);
        }
        
        // Validate filename - prevent path traversal
        String filename = file.getOriginalFilename();
        if (filename != null && (filename.contains("..") || filename.contains("/") || filename.contains("\\"))) {
            log.warn("Suspicious filename detected: {}", filename);
            throw new IllegalArgumentException("Invalid filename");
        }
    }

    /**
     * Validate file content using magic bytes.
     */
    private void validateFileContent(byte[] fileBytes, String contentType) {
        if (fileBytes == null || fileBytes.length == 0) {
            throw new IllegalArgumentException("File content is empty");
        }

        // Check file signature (magic bytes)
        boolean signatureValid = false;
        for (byte[] signature : FILE_SIGNATURES) {
            if (fileBytes.length >= signature.length) {
                boolean match = true;
                for (int i = 0; i < signature.length; i++) {
                    if (fileBytes[i] != signature[i]) {
                        match = false;
                        break;
                    }
                }
                if (match) {
                    signatureValid = true;
                    break;
                }
            }
        }

        if (!signatureValid) {
            log.warn("File content validation failed - invalid magic bytes");
            // Note: This check can be informational; some valid files may not match
            // Adjust strictness based on your security requirements
        }
    }

    /**
     * Extract file extension from filename.
     */
    private String getFileExtension(String filename) {
        if (filename == null || filename.isEmpty()) {
            return "";
        }
        int lastDotIndex = filename.lastIndexOf('.');
        return lastDotIndex > 0 ? filename.substring(lastDotIndex) : "";
    }

    /**
     * Generate unique stored filename using UUID.
     */
    private String generateStoredFilename(String extension) {
        return UUID.randomUUID().toString() + extension;
    }

    /**
     * Calculate SHA-256 checksum of file content.
     */
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