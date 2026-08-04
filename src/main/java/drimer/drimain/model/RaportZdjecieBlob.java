package drimer.drimain.model;

import jakarta.persistence.*;

@Entity
@Table(name = "raport_zdjecia_blob",
        uniqueConstraints = @UniqueConstraint(name = "uk_raport_blob_file", columnNames = {"raport_id", "stored_filename"}))
public class RaportZdjecieBlob {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "raport_id", nullable = false)
    private Raport raport;

    @Column(name = "stored_filename", nullable = false, length = 300)
    private String storedFilename;

    @Column(name = "content_type", length = 150)
    private String contentType;

    @Column(name = "file_size")
    private Long fileSize;

    @Basic(fetch = FetchType.LAZY)
    @Column(name = "data", nullable = false, columnDefinition = "bytea")
    private byte[] data;

    public Long getId() {
        return id;
    }

    public Raport getRaport() {
        return raport;
    }

    public void setRaport(Raport raport) {
        this.raport = raport;
    }

    public String getStoredFilename() {
        return storedFilename;
    }

    public void setStoredFilename(String storedFilename) {
        this.storedFilename = storedFilename;
    }

    public String getContentType() {
        return contentType;
    }

    public void setContentType(String contentType) {
        this.contentType = contentType;
    }

    public Long getFileSize() {
        return fileSize;
    }

    public void setFileSize(Long fileSize) {
        this.fileSize = fileSize;
    }

    public byte[] getData() {
        return data;
    }

    public void setData(byte[] data) {
        this.data = data;
    }
}

