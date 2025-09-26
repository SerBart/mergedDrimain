package drimer.drimain.model;

import jakarta.persistence.*;

@Entity
@Table(name = "instruction_parts")
public class InstructionPart {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "instruction_id")
    private Instruction instruction;

    @ManyToOne(optional = false)
    @JoinColumn(name = "part_id")
    private Part part;

    @Column(name = "ilosc")
    private Integer ilosc;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Instruction getInstruction() { return instruction; }
    public void setInstruction(Instruction instruction) { this.instruction = instruction; }
    public Part getPart() { return part; }
    public void setPart(Part part) { this.part = part; }
    public Integer getIlosc() { return ilosc; }
    public void setIlosc(Integer ilosc) { this.ilosc = ilosc; }
}

