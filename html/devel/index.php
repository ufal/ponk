<?php require('header.php') ?>

<div class="tab-content mt-1">
  <!-- Info Tab -->
  <div class="tab-pane fade" id="info">
    <?php require('info.php') ?>
  </div>

  <!-- Run Tab -->
  <div class="tab-pane fade show active" id="run">
    <?php require('run.php') ?>
  </div>

  <!-- API Reference Tab -->
  <div class="tab-pane fade" id="api">
    <?php require('api-reference.php') ?>
  </div>
</div>

<?php require('footer.php') ?>
