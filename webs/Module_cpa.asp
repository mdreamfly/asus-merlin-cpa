<% @ language="javascript" %>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
  <meta HTTP-EQUIV="Expires" CONTENT="-1">
  <title>CLIProxyAPI</title>
  <link rel="stylesheet" type="text/css" href="index_style.css">
  <link rel="stylesheet" type="text/css" href="form_style.css">
  <link rel="stylesheet" type="text/css" href="/res/softcenter.css">
  <style>
    .cpa-secret {
      font-family: monospace;
      word-break: break-all;
    }
    .cpa-result {
      color: #2f6fed;
      min-height: 20px;
      margin: 8px 16px;
    }
  </style>
  <script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
  <script language="JavaScript" type="text/javascript" src="/js/httpApi.js"></script>
  <script language="JavaScript" type="text/javascript" src="/state.js"></script>
  <script language="JavaScript" type="text/javascript" src="/general.js"></script>
  <script language="JavaScript" type="text/javascript" src="/popup.js"></script>
  <script language="JavaScript" type="text/javascript" src="/help.js"></script>
  <script language="JavaScript" type="text/javascript" src="/validator.js"></script>
  <script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
  <script language="JavaScript" type="text/javascript" src="/res/cpa-menu.js"></script>
  <script language="JavaScript" type="text/javascript" src="/res/softcenter.js"></script>
  <script>
    function setStatusText(text) {
      document.getElementById('cpa-status').textContent = text;
    }

    function setResultText(text) {
      document.getElementById('cpa-result').textContent = text || '';
    }

    function buildUiUrl(data) {
      var port = data.port || '3210';
      var path = data.uiPath || '/management.html';
      var host = window.location.hostname || 'router.asus.com';
      return 'http://' + host + ':' + port + path;
    }

    function renderManagementKey(secret) {
      var value = secret || '未初始化';
      document.getElementById('cpa-management-key').textContent = value;
      document.getElementById('cpa-copy-key').disabled = !secret;
    }

    function refreshHint(uiUrl) {
      document.getElementById('cpa-ui-link').href = uiUrl;
      document.getElementById('cpa-ui-link').textContent = uiUrl;
    }

    function renderStatus(data) {
      var uiUrl = buildUiUrl(data);
      document.getElementById('cpa-current-version').textContent = data.version || '-';
      document.getElementById('cpa-latest-version').textContent = data.latestVersion || '-';
      document.getElementById('cpa-port').textContent = data.port || '-';
      document.getElementById('cpa-update-flag').textContent = data.updateAvailable ? '有可用更新' : '已是最新';
      document.getElementById('cpa-last-check-time').textContent = data.lastCheckTime || '-';
      setStatusText(data.running ? '运行中' : '已停止');
      renderManagementKey(data.managementKey);
      refreshHint(uiUrl);
    }

    function buildStatusData(raw) {
      var port = raw.cpa_port || '3210';
      var running = raw.cpa_status === 'running';
      var updateAvailable = raw.cpa_update_available === '1' || raw.cpa_update_available === 1 || raw.cpa_update_available === true;
      return {
        running: running,
        version: raw.cpa_runtime_version || '-',
        latestVersion: raw.cpa_latest_version || raw.cpa_runtime_version || '-',
        updateAvailable: updateAvailable,
        lastCheckTime: raw.cpa_last_check_time || '-',
        port: port,
        uiPath: '/management.html',
        managementKey: raw.cpa_management_key || ''
      };
    }

    function requestJson(url, method, body, onSuccess, onError) {
      var xhr = new XMLHttpRequest();
      xhr.open(method, url, true);
      xhr.setRequestHeader('Cache-Control', 'no-cache');
      if (body) {
        xhr.setRequestHeader('Content-Type', 'application/json');
      }
      xhr.onreadystatechange = function() {
        var payload;
        if (xhr.readyState !== 4) {
          return;
        }
        if (xhr.status < 200 || xhr.status >= 300) {
          onError(xhr);
          return;
        }
        try {
          payload = JSON.parse(xhr.responseText);
        } catch (e) {
          onError(xhr);
          return;
        }
        onSuccess(payload);
      };
      xhr.send(body || null);
    }

    function requestDbusStatus(onSuccess, onError) {
      var cacheBustedUrl = '/_api/cpa?_t=' + new Date().getTime();
      requestJson(cacheBustedUrl, 'GET', null, function(payload) {
        var rows = payload && payload.result;
        var raw = rows && rows[0] ? rows[0] : null;
        if (!raw) {
          onError();
          return;
        }
        onSuccess(buildStatusData(raw));
      }, onError);
    }

    function invokeGatewayScript(script, action, onSuccess, onError) {
      var requestId = Math.floor(Math.random() * 100000000);
      requestJson('/_api/', 'POST', JSON.stringify({
        id: requestId,
        method: script,
        params: [action],
        fields: {}
      }), function(payload) {
        if (!payload || payload.result !== requestId) {
          onError();
          return;
        }
        onSuccess();
      }, onError);
    }

    function refreshStatus() {
      requestDbusStatus(function(data) {
        renderStatus(data);
        setResultText('状态已刷新。');
      }, function() {
        setStatusText('请求失败');
        setResultText('无法通过 softcenter /_api/cpa 获取 CPA 状态。');
      });
    }

    function actionLabel(action) {
      switch (action) {
        case 'start': return '启动';
        case 'stop': return '停止';
        case 'restart': return '重启';
        case 'check-update': return '检查更新';
        case 'update': return '执行更新';
        default: return action;
      }
    }

    function resolveActionTarget(action) {
      switch (action) {
        case 'start':
        case 'stop':
        case 'restart':
          return { script: 'cpa_config.sh', arg: action };
        case 'check-update':
          return { script: 'cpa_update.sh', arg: 'check' };
        case 'update':
          return { script: 'cpa_update.sh', arg: 'update' };
        default:
          throw new Error('unknown action');
      }
    }

    var cpaActionPollTimers = [];

    function clearActionPolling() {
      var i;
      for (i = 0; i < cpaActionPollTimers.length; i += 1) {
        window.clearTimeout(cpaActionPollTimers[i]);
      }
      cpaActionPollTimers = [];
    }

    function getActionPollDelays(action) {
      switch (action) {
        case 'check-update':
          return [1000, 2500, 5000, 8000, 12000];
        case 'update':
          return [1000, 3000, 6000, 10000, 15000, 20000, 30000, 45000, 60000];
        default:
          return [600, 1800, 3500];
      }
    }

    function getActionProgressText(action, step, total) {
      if (action === 'update') {
        return '执行更新处理中，正在同步状态（' + step + '/' + total + '）。';
      }
      if (action === 'check-update') {
        return '检查更新处理中，正在读取结果（' + step + '/' + total + '）。';
      }
      return actionLabel(action) + '处理中，正在同步状态（' + step + '/' + total + '）。';
    }

    function startActionPolling(action) {
      var delays = getActionPollDelays(action);
      var total = delays.length;
      var completed = 0;

      clearActionPolling();

      function poll(step, isLast) {
        requestDbusStatus(function(data) {
          var updateFinished = data.version === data.latestVersion && !data.updateAvailable;
          renderStatus(data);
          if (isLast) {
            if (action === 'update' && !updateFinished) {
              setResultText('执行更新尚未完成或更新失败，当前版本仍为 ' + data.version + '，请稍后重试或手动刷新确认。');
              return;
            }
            setResultText(actionLabel(action) + '已完成，状态已同步。');
            return;
          }
          setResultText(getActionProgressText(action, step, total));
        }, function() {
          if (isLast) {
            setStatusText('请求失败');
            setResultText(actionLabel(action) + '完成后状态同步失败，请手动刷新。');
            return;
          }
          setResultText(getActionProgressText(action, step, total) + ' 当前运行时可能正在重启。');
        });
      }

      poll(0, false);

      var index;
      for (index = 0; index < delays.length; index += 1) {
        (function(delay, isLast) {
          var timerId = window.setTimeout(function() {
            completed += 1;
            poll(completed, isLast);
          }, delay);
          cpaActionPollTimers.push(timerId);
        })(delays[index], index === total - 1);
      }
    }

    function invokeAction(action) {
      var target = resolveActionTarget(action);
      setStatusText('处理中...');
      setResultText(actionLabel(action) + '请求已发送，正在同步最终状态。');
      startActionPolling(action);
      invokeGatewayScript(target.script, target.arg, function() {
      }, function() {
        setResultText(actionLabel(action) + '请求已发送，接口确认失败，继续等待状态同步。');
      });
    }

    function copyManagementKey() {
      var secret = document.getElementById('cpa-management-key').textContent;
      if (!secret || secret === '未初始化') {
        setResultText('管理密钥尚未生成。');
        return;
      }

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(secret).then(function() {
          setResultText('管理密钥已复制。');
        }).catch(function() {
          copyManagementKeyLegacy(secret);
        });
        return;
      }

      copyManagementKeyLegacy(secret);
    }

    function copyManagementKeyLegacy(secret) {
      var textArea = document.createElement('textarea');
      textArea.value = secret;
      textArea.setAttribute('readonly', 'readonly');
      textArea.style.position = 'fixed';
      textArea.style.top = '-1000px';
      textArea.style.left = '-1000px';
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();

      try {
        if (document.execCommand && document.execCommand('copy')) {
          setResultText('管理密钥已复制。');
        } else {
          setResultText('复制失败，请手动复制管理密钥。');
        }
      } catch (e) {
        setResultText('复制失败，请手动复制管理密钥。');
      }

      document.body.removeChild(textArea);
    }

    function init() {
      show_menu(menu_hook);
      refreshStatus();
    }
  </script>
</head>
<body id="app" skin='<% nvram_get("sc_skin"); %>' onload="init();">
  <div id="TopBanner"></div>
  <div id="Loading" class="popup_bg"></div>
  <table class="content" align="center" cellpadding="0" cellspacing="0">
    <tr>
      <td width="17">&nbsp;</td>
      <td valign="top" width="202">
        <div id="mainMenu"></div>
        <div id="subMenu"></div>
      </td>
      <td valign="top">
        <div id="tabMenu" class="submenuBlock"></div>
        <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0" style="display: block;">
          <tr>
            <td align="left" valign="top">
              <div>
                <table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
                  <tr>
                    <td bgcolor="#4D595D" colspan="3" valign="top">
                      <div>&nbsp;</div>
                      <div class="formfonttitle">CLIProxyAPI</div>
                      <div style="float:right;width:15px;height:25px;margin-top:-20px;">
                        <img id="return_btn" onclick="reload_Soft_Center();" align="right" style="cursor:pointer;position:absolute;margin-left:-30px;margin-top:-25px;" title="返回软件中心" src="/images/backprev.png" onMouseOver="this.src='/images/backprevclick.png'" onMouseOut="this.src='/images/backprev.png'">
                      </div>
                      <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                      <div>
                        <table class="FormTable" border="1" cellpadding="4" cellspacing="0">
                          <tr>
                            <th>运行状态</th>
                            <td><span id="cpa-status">待检测</span></td>
                          </tr>
                          <tr>
                            <th>当前版本</th>
                            <td><span id="cpa-current-version">-</span></td>
                          </tr>
                          <tr>
                            <th>最新版本</th>
                            <td><span id="cpa-latest-version">-</span></td>
                          </tr>
                          <tr>
                            <th>监听端口</th>
                            <td><span id="cpa-port">-</span></td>
                          </tr>
                          <tr>
                            <th>更新状态</th>
                            <td><span id="cpa-update-flag">-</span></td>
                          </tr>
                          <tr>
                            <th>最近检查</th>
                            <td><span id="cpa-last-check-time">-</span></td>
                          </tr>
                          <tr>
                            <th>管理密钥</th>
                            <td>
                              <span class="cpa-secret" id="cpa-management-key">未初始化</span>
                              <input type="button" class="button_gen" value="复制" id="cpa-copy-key" onclick="copyManagementKey()" disabled>
                            </td>
                          </tr>
                          <tr>
                            <th>服务操作</th>
                            <td>
                              <input type="button" class="button_gen" value="启动" onclick="invokeAction('start')">
                              <input type="button" class="button_gen" value="停止" onclick="invokeAction('stop')">
                              <input type="button" class="button_gen" value="重启" onclick="invokeAction('restart')">
                            </td>
                          </tr>
                          <tr>
                            <th>更新操作</th>
                            <td>
                              <input type="button" class="button_gen" value="检查更新" onclick="invokeAction('check-update')">
                              <input type="button" class="button_gen" value="执行更新" onclick="invokeAction('update')">
                            </td>
                          </tr>
                          <tr>
                            <th>高级管理</th>
                            <td>
                              <a id="cpa-ui-link" href="#" target="_blank">打开管理界面</a>
                              <div style="color:#666;font-size:12px;margin-top:4px;">首次访问如提示认证，请输入上方管理密钥。</div>
                            </td>
                          </tr>
                        </table>
                        <div class="cpa-result" id="cpa-result"></div>
                      </div>
                    </td>
                  </tr>
                </table>
              </div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
  <div id="footer"></div>
</body>
</html>
