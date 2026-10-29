#pragma once

#include "logos_ui_plugin_context.h"
#include "rep_TorBackend_source.h"

#include <QTimer>

// Every tor_module call is made here; the QML renders. The event carries state changes at
// once; the poll carries progress details, the counts and the log, which move without one.
class TorBackend : public TorBackendSimpleSource, public LogosUiPluginContext {
    Q_OBJECT
public:
    explicit TorBackend(QObject* parent = nullptr);

    void reconnect() override;
    void forgetData() override;
    void setSocks(bool enabled, QString address) override;
    void refresh() override;

protected:
    void onContextReady() override;

private:
    void poll();
    void loadSettings();
    void applyStatus(const QString& payload);
    void restart(bool forget);

    QTimer* m_poll = nullptr;
};
