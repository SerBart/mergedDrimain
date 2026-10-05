package drimer.drimain.service;

import drimer.drimain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsPasswordService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class LegacyUserDetailsPasswordService implements UserDetailsPasswordService {

    private final UserRepository userRepository;

    @Override
    @Transactional
    public UserDetails updatePassword(UserDetails user, String newPassword) {
        return userRepository.findByUsername(user.getUsername())
                .map(entity -> {
                    entity.setPassword(newPassword);
                    userRepository.save(entity);
                    log.info("Upgraded legacy password encoding for user: {}", entity.getUsername());
                    return org.springframework.security.core.userdetails.User
                            .withUsername(entity.getUsername())
                            .password(entity.getPassword())
                            .authorities(entity.getRoles().stream().map(r -> r.getName()).toArray(String[]::new))
                            .build();
                })
                .orElse(user);
    }
}

