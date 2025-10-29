// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Secure Medical Data Sharing DApp
 * @dev Smart contract for secure and decentralized medical data sharing
 */
contract Project {
    
    struct MedicalRecord {
        string recordHash; // IPFS hash or encrypted data reference
        uint256 timestamp;
        address patient;
        address doctor;
        bool isActive;
    }
    
    struct AccessPermission {
        address authorizedEntity;
        uint256 expiryTime;
        bool isActive;
    }
    
    // Mappings
    mapping(uint256 => MedicalRecord) public medicalRecords;
    mapping(address => uint256[]) private patientRecords;
    mapping(uint256 => mapping(address => AccessPermission)) public accessPermissions;
    
    uint256 public recordCounter;
    
    // Events
    event RecordCreated(uint256 indexed recordId, address indexed patient, address indexed doctor, uint256 timestamp);
    event AccessGranted(uint256 indexed recordId, address indexed patient, address indexed authorizedEntity, uint256 expiryTime);
    event AccessRevoked(uint256 indexed recordId, address indexed patient, address indexed authorizedEntity);
    
    // Modifiers
    modifier onlyPatient(uint256 _recordId) {
        require(medicalRecords[_recordId].patient == msg.sender, "Only patient can perform this action");
        _;
    }
    
    modifier recordExists(uint256 _recordId) {
        require(_recordId < recordCounter, "Record does not exist");
        require(medicalRecords[_recordId].isActive, "Record is not active");
        _;
    }
    
    /**
     * @dev Core Function 1: Create a new medical record
     * @param _recordHash IPFS hash or encrypted reference to medical data
     * @param _doctor Address of the doctor creating the record
     */
    function createMedicalRecord(string memory _recordHash, address _doctor) public returns (uint256) {
        require(bytes(_recordHash).length > 0, "Record hash cannot be empty");
        require(_doctor != address(0), "Invalid doctor address");
        
        uint256 recordId = recordCounter;
        
        medicalRecords[recordId] = MedicalRecord({
            recordHash: _recordHash,
            timestamp: block.timestamp,
            patient: msg.sender,
            doctor: _doctor,
            isActive: true
        });
        
        patientRecords[msg.sender].push(recordId);
        recordCounter++;
        
        emit RecordCreated(recordId, msg.sender, _doctor, block.timestamp);
        
        return recordId;
    }
    
    /**
     * @dev Core Function 2: Grant access to a medical record
     * @param _recordId ID of the medical record
     * @param _authorizedEntity Address to grant access to
     * @param _duration Duration of access in seconds
     */
    function grantAccess(uint256 _recordId, address _authorizedEntity, uint256 _duration) 
        public 
        onlyPatient(_recordId) 
        recordExists(_recordId) 
    {
        require(_authorizedEntity != address(0), "Invalid address");
        require(_duration > 0, "Duration must be greater than 0");
        
        uint256 expiryTime = block.timestamp + _duration;
        
        accessPermissions[_recordId][_authorizedEntity] = AccessPermission({
            authorizedEntity: _authorizedEntity,
            expiryTime: expiryTime,
            isActive: true
        });
        
        emit AccessGranted(_recordId, msg.sender, _authorizedEntity, expiryTime);
    }
    
    /**
     * @dev Core Function 3: Revoke access to a medical record
     * @param _recordId ID of the medical record
     * @param _authorizedEntity Address to revoke access from
     */
    function revokeAccess(uint256 _recordId, address _authorizedEntity) 
        public 
        onlyPatient(_recordId) 
        recordExists(_recordId) 
    {
        require(accessPermissions[_recordId][_authorizedEntity].isActive, "Access not granted");
        
        accessPermissions[_recordId][_authorizedEntity].isActive = false;
        
        emit AccessRevoked(_recordId, msg.sender, _authorizedEntity);
    }
    
    /**
     * @dev Check if an entity has valid access to a record
     * @param _recordId ID of the medical record
     * @param _entity Address to check access for
     */
    function hasAccess(uint256 _recordId, address _entity) public view recordExists(_recordId) returns (bool) {
        // Patient always has access to their own records
        if (medicalRecords[_recordId].patient == _entity) {
            return true;
        }
        
        // Doctor who created the record has access
        if (medicalRecords[_recordId].doctor == _entity) {
            return true;
        }
        
        // Check if entity has valid permission
        AccessPermission memory permission = accessPermissions[_recordId][_entity];
        return permission.isActive && permission.expiryTime > block.timestamp;
    }
    
    /**
     * @dev Get all record IDs for a patient
     * @param _patient Address of the patient
     */
    function getPatientRecords(address _patient) public view returns (uint256[] memory) {
        return patientRecords[_patient];
    }
    
    /**
     * @dev Get medical record details (only if caller has access)
     * @param _recordId ID of the medical record
     */
    function getMedicalRecord(uint256 _recordId) 
        public 
        view 
        recordExists(_recordId) 
        returns (string memory recordHash, uint256 timestamp, address patient, address doctor) 
    {
        require(hasAccess(_recordId, msg.sender), "Access denied");
        
        MedicalRecord memory record = medicalRecords[_recordId];
        return (record.recordHash, record.timestamp, record.patient, record.doctor);
    }
}
