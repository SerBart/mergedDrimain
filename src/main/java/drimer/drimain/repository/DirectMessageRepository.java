package drimer.drimain.repository;

import drimer.drimain.model.DirectMessage;
import drimer.drimain.model.User;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface DirectMessageRepository extends JpaRepository<DirectMessage, Long> {

    @Query("""
            select m from DirectMessage m
            where (m.sender.id = :userA and m.recipient.id = :userB)
               or (m.sender.id = :userB and m.recipient.id = :userA)
            order by m.createdAt asc
            """)
    List<DirectMessage> findThread(@Param("userA") Long userA,
                                   @Param("userB") Long userB,
                                   Pageable pageable);

    @Query("""
            select m from DirectMessage m
            where (m.sender.id = :userA and m.recipient.id = :userB)
               or (m.sender.id = :userB and m.recipient.id = :userA)
            order by m.createdAt desc
            """)
    List<DirectMessage> findLatestBetween(@Param("userA") Long userA,
                                          @Param("userB") Long userB,
                                          Pageable pageable);

    List<DirectMessage> findByRecipientAndSenderAndReadAtIsNull(User recipient, User sender);

    long countByRecipientAndSenderAndReadAtIsNull(User recipient, User sender);
}

