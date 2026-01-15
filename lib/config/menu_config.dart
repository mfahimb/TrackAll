class MenuConfig {
  static const workStudy = "work_study";
  static const admin = "admin";

  static const downtimeEntry = "downtime_entry";
  static const nptReport = "npt_report";
  static const menuAssign = "menu_assign";

  static const Map<String, List<String>> menus = {
    workStudy: [
      downtimeEntry,
      nptReport,
    ],
    admin: [
      menuAssign,
    ],
  };
}
