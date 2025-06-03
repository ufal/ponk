
<div class="panel panel-info">
  <h3><?php echo $lang[$currentLang]['info_basic_label']; ?></h3>

  <?php
    if ($currentLang == 'cs') {
  ?>
      <div style="margin-left: 0px; margin-top: 8px; margin-bottom: 5px; margin-right: 5px"><?php require('about_cs.html') ?></div>
  <?php
    } else {
  ?>
      <div style="margin-left: 0px; margin-top: 8px; margin-bottom: 5px; margin-right: 5px"><?php require('about_en.html') ?></div>
  <?php
    }
  ?>


  <table class="table table-striped table-bordered">
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_authors']; ?></th>
      <td>Jiří Mírovský, Barbora Hladká, Michal Kuk, Silvie Cinková
      <br><?php echo $lang[$currentLang]['info_basic_authors_subapplication']; ?> 1 (<?php echo $lang[$currentLang]['info_basic_authors_app1_label']; ?>): Ivan Kraus, Arnold Stanovský
      <br><?php echo $lang[$currentLang]['info_basic_authors_subapplication']; ?> 2 (<?php echo $lang[$currentLang]['info_basic_authors_app2_label']; ?>): Jan Černý, Ivana Kvapilíková
      <!--br><?php echo $lang[$currentLang]['info_basic_authors_subapplication']; ?> 3: Silvie Cinková, ...-->
      </td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_homepage']; ?></th>
      <td><a href="http://ufal.mff.cuni.cz/ponk/" target="_blank">http://ufal.mff.cuni.cz/ponk/</a></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_repository']; ?></th>
      <td><a href="https://github.com/ufal/ponk" target="_blank">https://github.com/ufal/ponk</a></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_development_status']; ?></th>
      <td><?php echo $lang[$currentLang]['info_basic_development_status_development']; ?></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_OS']; ?></th>
      <td>Linux</td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_licence']; ?></th>
      <td><a href="https://www.mozilla.org/MPL/2.0/" target="_blank">MPL 2.0</a></td>
  </tr>
  <tr>
      <th><?php echo $lang[$currentLang]['info_basic_contact']; ?></th>
      <td><a href="mailto:mirovsky@ufal.mff.cuni.cz">mirovsky@ufal.mff.cuni.cz</a></td>
  </tr>
  </table>


  <!-- ================= ACKNOWLEDGEMENTS ================ -->

  <div class="mt-3 mb-3">
    <?php
      if ($currentLang == 'cs') {
    ?>
      <div><?php include('acknowledgements_cs.html'); ?></div>
    <?php
      } else {
    ?>
      <div><?php include('acknowledgements_en.html'); ?></div>
    <?php
      }
    ?>
  </div>

</div>
