package drimer.drimain.repository;

import drimer.drimain.model.AnnouncementAttachment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AnnouncementAttachmentRepository extends JpaRepository<AnnouncementAttachment, Long> {
    List<AnnouncementAttachment> findByAnnouncement_IdOrderByCreatedAtDesc(Long announcementId);
}

