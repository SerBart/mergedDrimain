package drimer.drimain.service;

import drimer.drimain.api.dto.AnnouncementDTO;
import drimer.drimain.api.dto.AnnouncementAttachmentDTO;
import drimer.drimain.api.dto.CreateAnnouncementRequest;
import drimer.drimain.model.Announcement;
import drimer.drimain.model.AnnouncementAttachment;
import drimer.drimain.model.AnnouncementTargetType;
import drimer.drimain.model.Dzial;
import drimer.drimain.model.NotificationType;
import drimer.drimain.model.User;
import drimer.drimain.repository.AnnouncementAttachmentRepository;
import drimer.drimain.repository.AnnouncementRepository;
import drimer.drimain.repository.DzialRepository;
import drimer.drimain.repository.UserRepository;
import drimer.drimain.config.AttachmentStorageConfig;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AnnouncementService {

    private final AnnouncementRepository announcementRepository;
    private final AnnouncementAttachmentRepository announcementAttachmentRepository;
    private final DzialRepository dzialRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;
    private final AttachmentStorageConfig storageConfig;

    @Transactional(readOnly = true)
    public List<AnnouncementDTO> listActive(Authentication authentication) {
        User currentUser = requireUser(authentication);
        return announcementRepository.findByActiveTrueOrderByCreatedAtDesc().stream()
                .filter(a -> isVisibleForUser(a, currentUser))
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public AnnouncementDTO create(Authentication authentication, CreateAnnouncementRequest request) {
        User author = requireUser(authentication);
        String cleanTitle = request.getTitle() == null ? "" : request.getTitle().trim();
        String cleanContent = request.getContent() == null ? "" : request.getContent().trim();
        AnnouncementTargetType targetType = parseTargetType(request.getTargetType());
        Dzial targetDzial = null;
        Set<User> targetUsers = new HashSet<>();

        if (cleanTitle.isEmpty()) {
            throw new IllegalArgumentException("Tytuł ogłoszenia jest wymagany");
        }
        if (cleanContent.isEmpty()) {
            throw new IllegalArgumentException("Treść ogłoszenia jest wymagana");
        }

        if (targetType == AnnouncementTargetType.DEPARTMENT) {
            Long dzialId = request.getTargetDzialId();
            if (dzialId == null) {
                throw new IllegalArgumentException("Dla targetu DEPARTMENT musisz wybrać dział");
            }
            targetDzial = dzialRepository.findById(dzialId)
                    .orElseThrow(() -> new IllegalArgumentException("Dział nie istnieje"));
        }

        if (targetType == AnnouncementTargetType.USERS) {
            List<Long> ids = request.getTargetUserIds() == null ? List.of() : request.getTargetUserIds().stream()
                    .filter(id -> id != null && id > 0)
                    .distinct()
                    .toList();
            if (ids.isEmpty()) {
                throw new IllegalArgumentException("Dla targetu USERS wybierz co najmniej jednego użytkownika");
            }
            List<User> foundUsers = userRepository.findAllById(ids);
            if (foundUsers.size() != ids.size()) {
                throw new IllegalArgumentException("Niektórzy użytkownicy z listy nie istnieją");
            }
            targetUsers.addAll(foundUsers);
        }

        Announcement announcement = new Announcement();
        announcement.setTitle(cleanTitle);
        announcement.setContent(cleanContent);
        announcement.setCreatedBy(author);
        announcement.setCreatedAt(Instant.now());
        announcement.setActive(true);
        announcement.setTargetType(targetType);
        announcement.setTargetDzial(targetDzial);
        announcement.setTargetUsers(targetUsers);

        Announcement saved = announcementRepository.save(announcement);

        notifyRecipients(saved, cleanTitle, cleanContent);

        return toDto(saved);
    }

    @Transactional
    public List<AnnouncementAttachmentDTO> uploadAttachments(Authentication authentication, Long announcementId, List<MultipartFile> files) {
        User author = requireUser(authentication);
        Announcement announcement = announcementRepository.findById(announcementId)
                .orElseThrow(() -> new IllegalArgumentException("Ogłoszenie nie istnieje"));
        if (files == null || files.isEmpty()) {
            return List.of();
        }

        Path storageDir = Paths.get(storageConfig.getBasePath(), "announcements");
        try {
            Files.createDirectories(storageDir);
        } catch (IOException e) {
            throw new RuntimeException("Nie udało się przygotować katalogu załączników", e);
        }

        List<AnnouncementAttachment> saved = new ArrayList<>();
        for (MultipartFile file : files) {
            validateFile(file);
            String original = file.getOriginalFilename() == null ? "attachment" : file.getOriginalFilename();
            String stored = UUID.randomUUID() + getFileExtension(original);
            Path fp = storageDir.resolve(stored);
            try {
                Files.copy(file.getInputStream(), fp, StandardCopyOption.REPLACE_EXISTING);
                AnnouncementAttachment attachment = new AnnouncementAttachment();
                attachment.setAnnouncement(announcement);
                attachment.setOriginalFilename(original);
                attachment.setStoredFilename(stored);
                attachment.setContentType(file.getContentType());
                attachment.setFileSize(file.getSize());
                attachment.setCreatedBy(author.getUsername());
                saved.add(announcementAttachmentRepository.save(attachment));
            } catch (IOException e) {
                throw new RuntimeException("Nie udało się zapisać pliku: " + original, e);
            }
        }

        return saved.stream().map(this::toAttachmentDto).toList();
    }

    @Transactional(readOnly = true)
    public Resource downloadAttachment(Long attachmentId) {
        AnnouncementAttachment attachment = announcementAttachmentRepository.findById(attachmentId)
                .orElseThrow(() -> new IllegalArgumentException("Załącznik nie istnieje"));
        Path fp = Paths.get(storageConfig.getBasePath(), "announcements", attachment.getStoredFilename());
        if (!Files.exists(fp)) {
            throw new IllegalArgumentException("Plik nie istnieje na dysku");
        }
        return new FileSystemResource(fp);
    }

    private void notifyRecipients(Announcement announcement, String cleanTitle, String cleanContent) {
        String shortContent = cleanContent.length() > 140 ? cleanContent.substring(0, 140) + "..." : cleanContent;

        if (announcement.getTargetType() == AnnouncementTargetType.ALL) {
            notificationService.createModuleNotification(
                    "Aktualnosci",
                    NotificationType.GENERIC,
                    "Nowe ogłoszenie: " + cleanTitle,
                    shortContent,
                    "/announcements"
            );
            return;
        }

        List<User> recipients;
        if (announcement.getTargetType() == AnnouncementTargetType.DEPARTMENT) {
            recipients = announcement.getTargetDzial() == null
                    ? List.of()
                    : userRepository.findByDzial_Id(announcement.getTargetDzial().getId());
        } else {
            recipients = new ArrayList<>(announcement.getTargetUsers());
        }

        for (User recipient : recipients) {
            notificationService.createPersonalNotification(
                    recipient,
                    NotificationType.GENERIC,
                    "Nowe ogłoszenie: " + cleanTitle,
                    shortContent,
                    "/announcements"
            );
        }
    }

    private AnnouncementTargetType parseTargetType(String raw) {
        if (raw == null || raw.isBlank()) {
            return AnnouncementTargetType.ALL;
        }
        try {
            return AnnouncementTargetType.valueOf(raw.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException("Nieprawidłowy targetType. Dozwolone: ALL, DEPARTMENT, USERS");
        }
    }

    private boolean isVisibleForUser(Announcement announcement, User user) {
        AnnouncementTargetType type = announcement.getTargetType() == null
                ? AnnouncementTargetType.ALL
                : announcement.getTargetType();

        if (type == AnnouncementTargetType.ALL) {
            return true;
        }
        if (type == AnnouncementTargetType.DEPARTMENT) {
            return announcement.getTargetDzial() != null
                    && user.getDzial() != null
                    && announcement.getTargetDzial().getId().equals(user.getDzial().getId());
        }
        return announcement.getTargetUsers().stream()
                .anyMatch(u -> u.getId() != null && u.getId().equals(user.getId()));
    }

    private void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Plik jest pusty");
        }
        if (file.getSize() > storageConfig.getMaxFileSizeBytes()) {
            throw new IllegalArgumentException("Plik jest za duży");
        }
        String ct = file.getContentType();
        if (ct == null || !storageConfig.getAllowedContentTypes().contains(ct)) {
            throw new IllegalArgumentException("Typ pliku nie jest dozwolony: " + ct);
        }
    }

    private String getFileExtension(String filename) {
        if (filename == null || filename.isEmpty()) {
            return "";
        }
        int idx = filename.lastIndexOf('.');
        return idx > 0 ? filename.substring(idx) : "";
    }

    private AnnouncementDTO toDto(Announcement a) {
        AnnouncementDTO dto = new AnnouncementDTO();
        AnnouncementTargetType targetType = a.getTargetType() == null ? AnnouncementTargetType.ALL : a.getTargetType();
        dto.setId(a.getId());
        dto.setTitle(a.getTitle());
        dto.setContent(a.getContent());
        dto.setCreatedAt(a.getCreatedAt());
        dto.setCreatedByUsername(a.getCreatedBy() != null ? a.getCreatedBy().getUsername() : null);
        dto.setActive(a.isActive());
        dto.setTargetType(targetType.name());
        dto.setTargetDzialId(a.getTargetDzial() != null ? a.getTargetDzial().getId() : null);
        dto.setTargetDzialNazwa(a.getTargetDzial() != null ? a.getTargetDzial().getNazwa() : null);

        if (targetType == AnnouncementTargetType.USERS) {
            dto.setTargetUserIds(safeTargetUserIds(a));
        } else {
            dto.setTargetUserIds(List.of());
        }

        dto.setAttachments(safeAttachments(a));
        return dto;
    }

    private List<Long> safeTargetUserIds(Announcement a) {
        try {
            return a.getTargetUsers().stream()
                    .map(User::getId)
                    .filter(id -> id != null)
                    .toList();
        } catch (Exception ex) {
            return List.of();
        }
    }

    private List<AnnouncementAttachmentDTO> safeAttachments(Announcement a) {
        try {
            return a.getAttachments().stream().map(this::toAttachmentDto).toList();
        } catch (Exception ex) {
            return Collections.emptyList();
        }
    }

    private AnnouncementAttachmentDTO toAttachmentDto(AnnouncementAttachment attachment) {
        AnnouncementAttachmentDTO dto = new AnnouncementAttachmentDTO();
        dto.setId(attachment.getId());
        dto.setOriginalFilename(attachment.getOriginalFilename());
        dto.setContentType(attachment.getContentType());
        dto.setFileSize(attachment.getFileSize());
        dto.setCreatedAt(attachment.getCreatedAt());
        dto.setCreatedBy(attachment.getCreatedBy());
        return dto;
    }

    private User requireUser(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalArgumentException("Brak zalogowanego użytkownika");
        }
        return userRepository.findByUsername(authentication.getName())
                .orElseThrow(() -> new IllegalArgumentException("Użytkownik nie istnieje"));
    }
}

