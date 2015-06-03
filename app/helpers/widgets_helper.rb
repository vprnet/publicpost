module WidgetsHelper
  def vpr_widget_header
    %{
    <script type='text/javascript'>
      var googletag = googletag || {};
      googletag.cmd = googletag.cmd || [];
      (function() {
        var gads = document.createElement('script');
        gads.async = true;
        gads.type = 'text/javascript';
        var useSSL = 'https:' == document.location.protocol;
        gads.src = (useSSL ? 'https:' : 'http:') +
          '//www.googletagservices.com/tag/js/gpt.js';
        var node = document.getElementsByTagName('script')[0];
        node.parentNode.insertBefore(gads, node);
      })();
    </script>

    <script type='text/javascript'>
      googletag.cmd.push(function() {
        googletag.defineSlot('/6634685/VPR_leaderboard_1', [728, 90], 'div-gpt-ad-1433274834163-0').addService(googletag.pubads());
        googletag.defineSlot('/6634685/VPR_medium_1', [300, 250], 'div-gpt-ad-1433274834163-1').setTargeting('Tags', ['Public Post']).addService(googletag.pubads());
        googletag.defineSlot('/6634685/VPR_medium_2', [300, 250], 'div-gpt-ad-1433274834163-2').addService(googletag.pubads());
        googletag.defineSlot('/6634685/VPR_medium_3', [300, 250], 'div-gpt-ad-1433274834163-3').addService(googletag.pubads());
        googletag.pubads().enableSingleRequest();
        googletag.enableServices();
      });
    </script>
    }.html_safe
  end

  def vpr_leader_board
    %{
      <!-- /6634685/VPR_leaderboard_1 -->
      <div id='div-gpt-ad-1433274834163-0' style='height:90px; width:728px;' class='vpr_leaderboard'>
      <script type='text/javascript'>
      googletag.cmd.push(function() { googletag.display('div-gpt-ad-1433274834163-0'); });
      </script>
      </div>
    }.html_safe
  end

  def vpr_medium_1
    %{
      <!-- /6634685/VPR_medium_1 -->
      <div id='div-gpt-ad-1433274834163-1' style='height:250px; width:300px;'>
      <script type='text/javascript'>
      googletag.cmd.push(function() { googletag.display('div-gpt-ad-1433274834163-1'); });
      </script>
      </div>
    }.html_safe
  end

  def vpr_medium_2
    %{
      <!-- /6634685/VPR_medium_2 -->
      <div id='div-gpt-ad-1433274834163-2' style='height:250px; width:300px;'>
      <script type='text/javascript'>
      googletag.cmd.push(function() { googletag.display('div-gpt-ad-1433274834163-2'); });
      </script>
      </div>
    }.html_safe
  end

  def vpr_medium_3
    %{
      <!-- /6634685/VPR_medium_3 -->
      <div id='div-gpt-ad-1433274834163-3' style='height:250px; width:300px;'>
      <script type='text/javascript'>
      googletag.cmd.push(function() { googletag.display('div-gpt-ad-1433274834163-3'); });
      </script>
      </div>
    }.html_safe
  end
end
