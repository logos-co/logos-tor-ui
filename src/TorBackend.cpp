#include "TorBackend.h"

#include "logos_sdk.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
constexpr int kPollMs = 2000;
constexpr int kLogLines = 200;
// A reconnect gives the old run 0.5 s to stop; a forget also deletes ~40 MB of files.
constexpr int kRestartTimeoutMs = 15000;

QJsonObject parse(const QString& s) { return QJsonDocument::fromJson(s.toUtf8()).object(); }
QString compact(const QJsonValue& v) {
    return v.isArray() ? QString::fromUtf8(QJsonDocument(v.toArray()).toJson(QJsonDocument::Compact))
                       : QString::fromUtf8(QJsonDocument(v.toObject()).toJson(QJsonDocument::Compact));
}
QString describe(const QString& e) { return e.isEmpty() ? QStringLiteral("unknown error") : e; }
QString describe(const logos::CallError& e) { return describe(QString::fromStdString(e.message)); }
}

TorBackend::TorBackend(QObject* parent) : TorBackendSimpleSource(parent) {}

void TorBackend::onContextReady() {
    // The callback runs on the IPC read stack, so it only queues.
    modules().tor_module.onStatus_changed([this](const QString& payload) {
        QTimer::singleShot(0, this, [this, payload] { applyStatus(payload); });
    });
    m_poll = new QTimer(this);
    m_poll->setInterval(kPollMs);
    connect(m_poll, &QTimer::timeout, this, [this] { poll(); });
    m_poll->start();
    loadSettings();
    poll();
}

void TorBackend::loadSettings() {
    if (!isContextReady()) return;
    modules().tor_module.settingsAsyncResult([this](logos::AsyncResult<QString> r) {
        if (r.ok() && parse(r.value).value("ok").toBool()) setSettingsJson(r.value);
    });
}

void TorBackend::setSocks(bool enabled, QString address) {
    if (!isContextReady()) return;
    setLastError({});
    modules().tor_module.set_socksAsyncResult(enabled, address, [this](logos::AsyncResult<QString> r) {
        if (!r.ok()) { setLastError(describe(r.error)); return; }
        const QJsonObject o = parse(r.value);
        if (o.value("ok").toBool()) setSettingsJson(r.value);
        else setLastError(describe(o.value("error").toString()));
        poll();
    });
}

void TorBackend::applyStatus(const QString& payload) {
    const QJsonObject o = parse(payload);
    if (!o.value("ok").toBool()) return;
    setState(o.value("state").toString());
    setStatusJson(payload);
}

void TorBackend::poll() {
    if (!isContextReady()) return;
    modules().tor_module.statusAsyncResult([this](logos::AsyncResult<QString> r) {
        if (!r.ok()) { setState(QStringLiteral("unavailable")); return; }
        const QJsonObject o = parse(r.value);
        if (!o.value("ok").toBool()) {
            // "starting": the module is loaded and has not opened Tor yet.
            const QString e = o.value("error").toString();
            const QString state = e == QLatin1String("starting") ? QStringLiteral("connecting") : QStringLiteral("failed");
            setStatusJson(QString::fromUtf8(QJsonDocument(QJsonObject{{"ok", true}, {"state", state}, {"progress", 0}, {"detail", e}})
                                                .toJson(QJsonDocument::Compact)));
            setState(state);
            return;
        }
        applyStatus(r.value);
    });
    modules().tor_module.usageAsyncResult([this](logos::AsyncResult<QString> r) {
        if (!r.ok()) return;
        const QJsonObject o = parse(r.value);
        if (o.value("ok").toBool()) setUsageJson(r.value);
        else setLastError(describe(o.value("error").toString()));
    });
    modules().tor_module.log_tailAsyncResult(kLogLines, [this](logos::AsyncResult<QString> r) {
        if (!r.ok()) return;
        const QJsonObject o = parse(r.value);
        if (o.value("ok").toBool()) setLogJson(compact(o.value("entries")));
    });
}

void TorBackend::restart(bool forget) {
    if (!isContextReady() || busy()) return;
    setBusy(true);
    setLastError({});
    auto done = [this](logos::AsyncResult<QString> r) {
        setBusy(false);
        if (!r.ok()) setLastError(describe(r.error));
        else if (!parse(r.value).value("ok").toBool()) setLastError(describe(parse(r.value).value("error").toString()));
        poll();
    };
    if (forget) modules().tor_module.forget_dataAsyncResult(done, Timeout(kRestartTimeoutMs));
    else modules().tor_module.reconnectAsyncResult(done, Timeout(kRestartTimeoutMs));
}

void TorBackend::reconnect() { restart(false); }

void TorBackend::forgetData() { restart(true); }

void TorBackend::refresh() {
    loadSettings();
    poll();
}
