package drimer.drimain.repository.spec;

import drimer.drimain.model.Raport;
import drimer.drimain.model.enums.RaportStatus;
import org.springframework.data.jpa.domain.Specification;

import java.time.LocalDate;

public class RaportSpecifications {

    public static Specification<Raport> hasStatus(RaportStatus status) {
        return (root, q, cb) ->
                status == null ? cb.conjunction() : cb.equal(root.get("status"), status);
    }

    public static Specification<Raport> hasMaszynaId(Long id) {
        return (root, q, cb) ->
                id == null ? cb.conjunction() : cb.equal(root.get("maszyna").get("id"), id);
    }

    public static Specification<Raport> dateFrom(LocalDate from) {
        return (root, q, cb) ->
                from == null ? cb.conjunction() : cb.greaterThanOrEqualTo(root.get("dataNaprawy"), from);
    }

    public static Specification<Raport> dateTo(LocalDate to) {
        return (root, q, cb) ->
                to == null ? cb.conjunction() : cb.lessThanOrEqualTo(root.get("dataNaprawy"), to);
    }

    public static Specification<Raport> fullText(String qStr) {
        return (root, q, cb) -> {
            if (qStr == null || qStr.isBlank()) return cb.conjunction();
            String like = "%" + qStr.toLowerCase() + "%";
            return cb.or(
                cb.like(cb.lower(root.get("typNaprawy")), like),
                cb.like(cb.lower(root.get("opis")), like)
            );
        };
    }
}