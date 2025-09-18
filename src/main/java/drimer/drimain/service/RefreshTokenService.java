package drimer.drimain.service;

import drimer.drimain.model.RefreshToken;
import drimer.drimain.model.User;
import drimer.drimain.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class RefreshTokenService {

    private final RefreshTokenRepository refreshTokenRepository;

    @Value("${app.jwt.refresh-expiration:604800000}") // 7 days default
    private long refreshExpirationMs;

    @Transactional
    public RefreshToken createRefreshToken(User user) {
        // Revoke any existing tokens for this user
        refreshTokenRepository.revokeAllByUser(user);
        
        String tokenValue = UUID.randomUUID().toString();
        LocalDateTime expiry = LocalDateTime.now().plusSeconds(refreshExpirationMs / 1000);
        
        RefreshToken refreshToken = new RefreshToken(user, tokenValue, expiry);
        RefreshToken saved = refreshTokenRepository.save(refreshToken);
        
        log.info("Created refresh token for user: {}", user.getUsername());
        return saved;
    }

    public Optional<RefreshToken> findByToken(String token) {
        return refreshTokenRepository.findByToken(token);
    }

    @Transactional
    public RefreshToken verifyExpiration(RefreshToken token) {
        if (token.isExpired()) {
            refreshTokenRepository.delete(token);
            throw new RuntimeException("Refresh token was expired. Please make a new signin request");
        }
        return token;
    }

    @Transactional
    public void revokeByUser(User user) {
        refreshTokenRepository.revokeAllByUser(user);
        log.info("Revoked all refresh tokens for user: {}", user.getUsername());
    }

    @Transactional
    public void revokeByToken(String token) {
        refreshTokenRepository.revokeByToken(token);
        log.info("Revoked refresh token: {}", token.substring(0, Math.min(8, token.length())));
    }

    @Transactional
    public void cleanupExpiredTokens() {
        refreshTokenRepository.deleteExpiredTokens(LocalDateTime.now());
        log.debug("Cleaned up expired refresh tokens");
    }
}