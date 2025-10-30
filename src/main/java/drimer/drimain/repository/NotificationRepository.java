package drimer.drimain.repository;

import drimer.drimain.model.Notification;
import drimer.drimain.model.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    List<Notification> findByUserOrderByCreatedAtDesc(User user);
    List<Notification> findByModuleIgnoreCaseOrderByCreatedAtDesc(String module);
    List<Notification> findByUserIsNullAndModuleIgnoreCaseOrderByCreatedAtDesc(String module);
}

