package cmd


import (
	"encoding/json"
	"os"
	"os/signal"
	"syscall"

	"github.com/apernet/hysteria/core/v2/client"
	"go.uber.org/zap"
)

var (
	globalClient  client.Client
	isCoreRunning bool
)

func StartTunnel(jsonConfig string) {
	initLogger()

	var config clientConfig
	err := json.Unmarshal([]byte(jsonConfig), &config)
	if err != nil {
		logger.Error("failed to parse JSON config", zap.Error(err))
		return
	}

	c, err := client.NewReconnectableClient(
		config.Config,
		func(c client.Client, info *client.HandshakeInfo, count int) {
			connectLog(info, count)
			if count == 1 && !disableUpdateCheck {
				go runCheckUpdateClient(c)
			}
		},
		config.Lazy,
	)
	if err != nil {
		logger.Error("failed to initialize client", zap.Error(err))
		return
	}
	defer c.Close()

	globalClient = c
	isCoreRunning = true

	var runner clientModeRunner
	if config.SOCKS5 != nil {
		runner.Add("SOCKS5 server", func() error { return clientSOCKS5(*config.SOCKS5, c) })
	}
	if config.HTTP != nil {
		runner.Add("HTTP proxy server", func() error { return clientHTTP(*config.HTTP, c) })
	}
	if len(config.TCPForwarding) > 0 {
		runner.Add("TCP forwarding", func() error { return clientTCPForwarding(config.TCPForwarding, c) })
	}
	if len(config.UDPForwarding) > 0 {
		runner.Add("UDP forwarding", func() error { return clientUDPForwarding(config.UDPForwarding, c) })
	}
	if config.TCPTProxy != nil {
		runner.Add("TCP transparent proxy", func() error { return clientTCPTProxy(*config.TCPTProxy, c) })
	}
	if config.UDPTProxy != nil {
		runner.Add("UDP transparent proxy", func() error { return clientUDPTProxy(*config.UDPTProxy, c) })
	}
	if config.TCPRedirect != nil {
		runner.Add("TCP redirect", func() error { return clientTCPRedirect(*config.TCPRedirect, c) })
	}
	if config.TUN != nil {
		runner.Add("TUN", func() error { return clientTUN(*config.TUN, c) })
	}

	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signalChan)

	runnerChan := make(chan clientModeRunnerResult, 1)
	go func() {
		runnerChan <- runner.Run()
	}()

	select {
	case <-signalChan:
		logger.Info("received signal, shutting down gracefully")
	case r := <-runnerChan:
		if r.OK {
			logger.Info(r.Msg)
		} else {
			_ = c.Close()
			logger.Error(r.Msg, zap.Error(r.Err))
		}
	}

	isCoreRunning = false
}

func GetCoreState() bool {
	return isCoreRunning
}

func StopTunnel() {
	if globalClient != nil {
		_ = globalClient.Close()
		logger.Info("Tunnel shutdown successful")
	}
	isCoreRunning = false
}