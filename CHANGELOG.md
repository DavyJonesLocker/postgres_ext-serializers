# CHANGELOG

## 0.0.4 - 2014-12-13

### Added
- Nothing.

### Deprecated
- Class methods on serializers for computed properties have been deprecated,
  these should now be instance methods and alias like `current_user` can now
  be used so no longer has `scope` argument. Sql computed properties on models
  are still class methods.

### Removed
- Nothing.

### Fixed
- Fixed generation of SQL for github issues #18 and #20
- Returns `[]` instead of `null` if data empty, required by frameworks like ember
- Use postgres `json_agg` function if available
- Fixed relation "" does not exist error

## 0.0.3 - 2014-09-01

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Supports options `each_serializer` and `serializer` when specified in
  the controller or in the serializers

## 0.0.2 - 2014-08-22

### Added
- Rails 4.1 support

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Nothing.
