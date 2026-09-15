package drimer.drimain.model;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Getter @Setter
@Table(name="parts")
public class Part {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable=false)
    private String nazwa;

    @Column(nullable=false)
    private String kod;

    @Column(length = 2000)
    private String opis;

    private String kategoria;

    private Integer ilosc;
    private Integer minIlosc;
    private String jednostka;

    @Column(name = "data_zakupu")
    private LocalDate dataZakupu;

    @Column(name = "data_realizacji")
    private LocalDate dataRealizacji;

    @Column(precision = 12, scale = 2)
    private BigDecimal cena;

    // new optional assignment to a machine
    @ManyToOne
    private Maszyna maszyna;
}