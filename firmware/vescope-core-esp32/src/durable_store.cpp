#include "durable_store.h"

#include <FS.h>
#include <Preferences.h>
#include <SPIFFS.h>

#include "config.h"

namespace vescope {

namespace {
Preferences durable_prefs;
constexpr char TELEMETRY_PATH[] = "/telemetry.q";
constexpr char TELEMETRY_TMP_PATH[] = "/telemetry.tmp";
constexpr char SESSION_PATH[] = "/sessions.q";
constexpr char SESSION_TMP_PATH[] = "/sessions.tmp";
constexpr uint32_t TELEMETRY_MAGIC = 0x56535132U;  // "VSQ2"
constexpr size_t SESSION_QUEUE_MAX_BYTES = 64U * 1024U;

#pragma pack(push, 1)
struct DiskTelemetry {
  uint32_t magic;
  uint32_t crc32;
  DurableTelemetry payload;
};
#pragma pack(pop)

uint32_t fnv1a(const uint8_t* data, size_t size) {
  uint32_t hash = 2166136261UL;
  for (size_t i = 0; i < size; ++i) {
    hash ^= data[i];
    hash *= 16777619UL;
  }
  return hash;
}

uint32_t recordCrc(const DiskTelemetry& input) {
  DiskTelemetry copy = input;
  copy.crc32 = 0;
  return fnv1a(reinterpret_cast<const uint8_t*>(&copy), sizeof(copy));
}

bool recordValid(const DiskTelemetry& record) {
  return record.magic == TELEMETRY_MAGIC && record.crc32 == recordCrc(record);
}

size_t fileSize(const char* path) {
  File file = SPIFFS.open(path, FILE_READ);
  if (!file) return 0;
  const size_t size = file.size();
  file.close();
  return size;
}

bool copyTail(const char* source_path, const char* tmp_path, uint32_t head) {
  File source = SPIFFS.open(source_path, FILE_READ);
  if (!source) return false;
  const size_t size = source.size();
  if (head > size || !source.seek(head, SeekSet)) {
    source.close();
    return false;
  }

  SPIFFS.remove(tmp_path);
  File target = SPIFFS.open(tmp_path, FILE_WRITE);
  if (!target) {
    source.close();
    return false;
  }

  uint8_t buffer[512];
  bool ok = true;
  while (source.available()) {
    const size_t count = source.read(buffer, sizeof(buffer));
    if (count == 0) break;
    if (target.write(buffer, count) != count) {
      ok = false;
      break;
    }
  }
  target.flush();
  target.close();
  source.close();

  if (!ok) {
    SPIFFS.remove(tmp_path);
    return false;
  }
  return true;
}
}  // namespace

bool DurableStore::begin() {
  durable_prefs.begin("vescope-q", false);

  const bool initialized = durable_prefs.getBool("fsinit", false);
  fs_ok_ = SPIFFS.begin(false);
  if (!fs_ok_ && !initialized) {
    if (SPIFFS.format()) fs_ok_ = SPIFFS.begin(false);
  }
  if (fs_ok_) durable_prefs.putBool("fsinit", true);
  if (!fs_ok_) return false;

  boot_id_ = durable_prefs.getULong("boot", 0) + 1U;
  if (boot_id_ == 0) boot_id_ = 1;
  durable_prefs.putULong("boot", boot_id_);

  telemetry_head_ = durable_prefs.getULong("thead", 0);
  session_head_ = durable_prefs.getULong("shead", 0);

  const size_t telemetry_size = fileSize(TELEMETRY_PATH);
  if (telemetry_head_ > telemetry_size) {
    telemetry_head_ = 0;
    durable_prefs.putULong("thead", 0);
  }
  const size_t session_size = fileSize(SESSION_PATH);
  if (session_head_ > session_size) {
    session_head_ = 0;
    durable_prefs.putULong("shead", 0);
  }
  return true;
}

bool DurableStore::healthy() const { return fs_ok_; }
uint32_t DurableStore::bootId() const { return boot_id_; }

bool DurableStore::compactTelemetry() {
  if (!fs_ok_) return false;
  const size_t size = fileSize(TELEMETRY_PATH);
  if (size == 0 || telemetry_head_ == 0) return true;

  if (telemetry_head_ >= size) {
    SPIFFS.remove(TELEMETRY_PATH);
    telemetry_head_ = 0;
    persistTelemetryHead(true);
    return true;
  }

  if (!copyTail(TELEMETRY_PATH, TELEMETRY_TMP_PATH, telemetry_head_)) return false;
  SPIFFS.remove(TELEMETRY_PATH);
  if (!SPIFFS.rename(TELEMETRY_TMP_PATH, TELEMETRY_PATH)) return false;
  telemetry_head_ = 0;
  persistTelemetryHead(true);
  return true;
}

bool DurableStore::enqueueTelemetry(const DurableTelemetry& payload) {
  if (!fs_ok_) return false;

  size_t size = fileSize(TELEMETRY_PATH);
  if (size + sizeof(DiskTelemetry) > DURABLE_QUEUE_MAX_BYTES && telemetry_head_ > 0) {
    if (!compactTelemetry()) return false;
    size = fileSize(TELEMETRY_PATH);
  }
  if (size + sizeof(DiskTelemetry) > DURABLE_QUEUE_MAX_BYTES) return false;

  DiskTelemetry record{};
  record.magic = TELEMETRY_MAGIC;
  record.payload = payload;
  record.crc32 = recordCrc(record);

  File file = SPIFFS.open(TELEMETRY_PATH, FILE_APPEND);
  if (!file) return false;
  const size_t written = file.write(reinterpret_cast<const uint8_t*>(&record), sizeof(record));
  file.flush();
  file.close();
  return written == sizeof(record);
}

bool DurableStore::peekTelemetry(DurableTelemetry& payload) {
  if (!fs_ok_) return false;
  File file = SPIFFS.open(TELEMETRY_PATH, FILE_READ);
  if (!file) return false;
  const size_t size = file.size();
  if (telemetry_head_ + sizeof(DiskTelemetry) > size || !file.seek(telemetry_head_, SeekSet)) {
    file.close();
    return false;
  }

  DiskTelemetry record{};
  const size_t read = file.read(reinterpret_cast<uint8_t*>(&record), sizeof(record));
  file.close();
  if (read != sizeof(record) || !recordValid(record)) return false;
  payload = record.payload;
  return true;
}

void DurableStore::persistTelemetryHead(bool force) {
  if (!force && telemetry_pops_since_checkpoint_ < DURABLE_HEAD_CHECKPOINT_EVERY) return;
  durable_prefs.putULong("thead", telemetry_head_);
  telemetry_pops_since_checkpoint_ = 0;
}

bool DurableStore::popTelemetry() {
  if (!fs_ok_) return false;
  const size_t size = fileSize(TELEMETRY_PATH);
  if (size == 0 || telemetry_head_ + sizeof(DiskTelemetry) > size) return false;

  telemetry_head_ += sizeof(DiskTelemetry);
  ++telemetry_pops_since_checkpoint_;

  if (telemetry_head_ >= size) {
    SPIFFS.remove(TELEMETRY_PATH);
    telemetry_head_ = 0;
    persistTelemetryHead(true);
  } else {
    persistTelemetryHead(false);
    if (telemetry_head_ >= 64U * 1024U && telemetry_head_ > size / 2U) {
      compactTelemetry();
    }
  }
  return true;
}

size_t DurableStore::pendingTelemetry() const {
  if (!fs_ok_) return 0;
  const size_t size = fileSize(TELEMETRY_PATH);
  if (size <= telemetry_head_) return 0;
  return (size - telemetry_head_) / sizeof(DiskTelemetry);
}

size_t DurableStore::telemetryBytes() const {
  if (!fs_ok_) return 0;
  const size_t size = fileSize(TELEMETRY_PATH);
  return size > telemetry_head_ ? size - telemetry_head_ : 0;
}

bool DurableStore::compactSessionSummaries() {
  if (!fs_ok_) return false;
  const size_t size = fileSize(SESSION_PATH);
  if (size == 0 || session_head_ == 0) return true;

  if (session_head_ >= size) {
    SPIFFS.remove(SESSION_PATH);
    session_head_ = 0;
    durable_prefs.putULong("shead", 0);
    return true;
  }

  if (!copyTail(SESSION_PATH, SESSION_TMP_PATH, session_head_)) return false;
  SPIFFS.remove(SESSION_PATH);
  if (!SPIFFS.rename(SESSION_TMP_PATH, SESSION_PATH)) return false;
  session_head_ = 0;
  durable_prefs.putULong("shead", 0);
  return true;
}

bool DurableStore::enqueueSessionSummary(const String& payload) {
  if (!fs_ok_ || payload.length() == 0) return false;

  size_t size = fileSize(SESSION_PATH);
  const size_t required = payload.length() + 1U;
  if (size + required > SESSION_QUEUE_MAX_BYTES && session_head_ > 0) {
    if (!compactSessionSummaries()) return false;
    size = fileSize(SESSION_PATH);
  }
  if (size + required > SESSION_QUEUE_MAX_BYTES) return false;

  File file = SPIFFS.open(SESSION_PATH, FILE_APPEND);
  if (!file) return false;
  const size_t written = file.print(payload);
  const size_t newline = file.print('\n');
  file.flush();
  file.close();
  return written == payload.length() && newline == 1;
}

bool DurableStore::peekSessionSummary(String& payload) {
  payload = "";
  if (!fs_ok_) return false;
  File file = SPIFFS.open(SESSION_PATH, FILE_READ);
  if (!file) return false;
  const size_t size = file.size();
  if (session_head_ >= size || !file.seek(session_head_, SeekSet)) {
    file.close();
    return false;
  }

  while (file.available()) {
    const char c = static_cast<char>(file.read());
    if (c == '\n') break;
    payload += c;
    if (payload.length() > 4096) {
      payload = "";
      file.close();
      return false;
    }
  }
  file.close();
  return payload.length() > 0;
}

bool DurableStore::popSessionSummary() {
  if (!fs_ok_) return false;
  File file = SPIFFS.open(SESSION_PATH, FILE_READ);
  if (!file) return false;
  const size_t size = file.size();
  if (session_head_ >= size || !file.seek(session_head_, SeekSet)) {
    file.close();
    return false;
  }

  uint32_t consumed = 0;
  while (file.available()) {
    ++consumed;
    if (static_cast<char>(file.read()) == '\n') break;
  }
  file.close();
  if (consumed == 0) return false;

  session_head_ += consumed;
  if (session_head_ >= size) {
    SPIFFS.remove(SESSION_PATH);
    session_head_ = 0;
  } else if (session_head_ >= 16U * 1024U && session_head_ > size / 2U) {
    compactSessionSummaries();
  }
  durable_prefs.putULong("shead", session_head_);
  return true;
}

size_t DurableStore::pendingSessionSummaries() const {
  if (!fs_ok_) return 0;
  File file = SPIFFS.open(SESSION_PATH, FILE_READ);
  if (!file) return 0;
  const size_t size = file.size();
  if (session_head_ >= size || !file.seek(session_head_, SeekSet)) {
    file.close();
    return 0;
  }

  size_t count = 0;
  while (file.available()) {
    if (static_cast<char>(file.read()) == '\n') ++count;
  }
  file.close();
  return count;
}

}  // namespace vescope
