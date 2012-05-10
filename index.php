<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>dstatAggregator</title>
    <style type="text/css">
      table, th, td {
        border: 1px solid gray;
        border-collapse: collapse;
        padding: 2px 4px;
      }
    </style>
  </head>
  <body>
    <h1>dstatAggregator</h1>
    <p>他の二つほどきちんとエラー処理していないので気をつけてください。</p>
    <form action="dstat2rrd.php" method="post" enctype="multipart/form-data">
      <fieldset>
        <legend>ファイル登録</legend>
        <input type="file" name="csv_file" size="50" />
        <input type="submit" value="Upload" />
      </fieldset>
    </form>
    <form action="rrds2graphs.php" method="post">
      <fieldset>
        <legend>グラフ作成</legend>
        <table>
          <tr>
            <th>id</th>
            <th>rrd_name</th>
            <th>hostname</th>
            <th>start_time</th>
            <th>duration</th>
            <th>disk</th>
            <th>net</th>
            <th>created_at</th>
          </tr>
<?php
$conn = new mysqli('localhost', 'rstat', 'rstat', 'rstat');

if ($conn->connect_errno) {
    die('Connection Failed: ' . $conn->connect_errno);
}

$conn->set_charset('utf8');
$conn->autocommit(FALSE);
$stmt = $conn->prepare('SELECT id, rrd_name, hostname, start_time, duration, devices_disk, devices_net, created_at FROM rrd ORDER BY id');
$stmt->execute();
$stmt->bind_result($id, $rrd_name, $hostname, $start_time, $duration, $devices_disk, $devices_net, $created_at);

while ($stmt->fetch()) {
    $disks = preg_split('/,/', $devices_disk);
    $nets = preg_split('/,/', $devices_net);
?>
          <tr>
            <td><input type="checkbox" name="ids[]" value="<?php echo htmlspecialchars($id); ?>" /><?php echo htmlspecialchars($id); ?></td>
            <td><?php echo htmlspecialchars($rrd_name); ?></td>
            <td><?php echo htmlspecialchars($hostname); ?></td>
            <td><?php echo htmlspecialchars($start_time); ?></td>
            <td><?php echo htmlspecialchars($duration); ?></td>
            <td>
              <input type="radio" name="disk<?php echo htmlspecialchars($id); ?>" value="total" checked />total
<?php
    foreach ($disks as $disk) {
?>
              <input type="radio" name="disk<?php echo htmlspecialchars($id); ?>" value="<?php echo htmlspecialchars($disk); ?>" /><?php echo htmlspecialchars($disk); ?>
              
<?php
    }
?>
            </td>
            <td>
              <input type="radio" name="net<?php echo htmlspecialchars($id); ?>" value="total" checked />total
<?php
    foreach ($nets as $net) {
?>
              <input type="radio" name="net<?php echo htmlspecialchars($id); ?>" value="<?php echo htmlspecialchars($net); ?>" /><?php echo htmlspecialchars($net); ?>
              
<?php
    }
?>
            </td>
            <td><?php echo htmlspecialchars($created_at); ?></td>
          </tr>
          <input type="hidden" name="rrd<?php echo htmlspecialchars($id); ?>" value="<?php echo htmlspecialchars($rrd_name); ?>" />
          <input type="hidden" name="host<?php echo htmlspecialchars($id); ?>" value="<?php echo htmlspecialchars($hostname); ?>" />
<?php
}

$stmt->close();
$conn->rollback();
$conn->close();
?>
        </table>
        Width<input type="text" name="width" value="512" /><br />
        Height<input type="text" name="height" value="192" /><br />
        Disk I/O upper limit<input type="text" name="disk_limit" value="0" /> (Bytes/sec)<br />
        Network I/O upper limit<input type="text" name="net_limit" value="0" /> (Bytes/sec)<br />
        <label for="aggregate">
          <input type="radio" name="switch" value="aggregate" id="aggregate" checked />
          Aggregate
        </label>
        <label for="delete">
          <input type="radio" name="switch" value="delete" id="delete" />
          Delete
        </label>
        <br />
        <input type="submit" value="Submit" />
        <input type="reset" value="Reset" />
      </fieldset>
    </form>
    <hr />
    (c) 2012, Sadao Hiratsuka.
  </body>
</html>

