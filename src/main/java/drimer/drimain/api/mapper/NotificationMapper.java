package drimer.drimain.api.mapper;

import drimer.drimain.api.dto.NotificationDTO;
import drimer.drimain.model.Notification;

public class NotificationMapper {
    public static NotificationDTO toDto(Notification n) {
        if (n == null) return null;
        NotificationDTO dto = new NotificationDTO();
        dto.setId(n.getId());
        dto.setModule(n.getModule());
        dto.setType(n.getType());
        dto.setTitle(n.getTitle());
        dto.setMessage(n.getMessage());
        dto.setLink(n.getLink());
        dto.setCreatedAt(n.getCreatedAt());
        dto.setRead(n.isRead());
        return dto;
    }
}

