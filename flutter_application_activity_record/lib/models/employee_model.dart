// อ้างอิงจาก ตาราง 3.2 ตารางเก็บข้อมูลพนักงาน (EMPLOYEE)
class Employee {
  final String empId;
  // *** เพิ่มตัวแปรนี้เข้ามา ***
  final int? companyId; // ID ของบริษัทที่พนักงานสังกัด
  final String empNameTh;
  final String empNameEn;
  final String empPosition;
  final String? depId;
  final String empPhone;
  final String empEmail;
  final String empPassword;
  final DateTime empStartDate;
  final String empStatus;
  final String empRole;

  Employee({
    required this.empId,
    this.companyId, // *** เพิ่มใน constructor ***
    required this.empNameTh,
    required this.empNameEn,
    required this.empPosition,
    this.depId,
    required this.empPhone,
    required this.empEmail,
    required this.empPassword,
    required this.empStartDate,
    required this.empStatus,
    required this.empRole,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      empId: json['EMP_ID'],
      companyId: json['COMPANY_ID'], // *** เพิ่มการดึงค่าจาก JSON ***
      empNameTh: json['EMP_NAME_TH'],
      empNameEn: json['EMP_NAME_EN'],
      empPosition: json['EMP_POSITION'],
      depId: json['DEP_ID'],
      empPhone: json['EMP_PHONE'],
      empEmail: json['EMP_EMAIL'],
      empPassword: json['EMP_PASSWORD'],
      empStartDate: DateTime.parse(json['EMP_STARTDATE']),
      empStatus: json['EMP_STATUS'],
      empRole: json['EMP_ROLE'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'EMP_ID': empId,
      'COMPANY_ID': companyId, // *** เพิ่มการส่งค่าไป JSON ***
      'EMP_NAME_TH': empNameTh,
      'EMP_NAME_EN': empNameEn,
      'EMP_POSITION': empPosition,
      'DEP_ID': depId,
      'EMP_PHONE': empPhone,
      'EMP_EMAIL': empEmail,
      'EMP_PASSWORD': empPassword,
      'EMP_STARTDATE': empStartDate.toIso8601String(),
      'EMP_STATUS': empStatus,
      'EMP_ROLE': empRole,
    };
  }
}
