var onLoad = function() {
  // Prevent JS being loaded twice
  if ($("body").attr("data-js-loaded") === "true") {
    return false
  }

  var $target = $(".js-orcid-profile")

  if ($target.length > 0) {
    $.ajax({
      dataType: "html",
      url: $target.data("orcid-profile-path"),
      beforeSend: function(_xhr, _settings) {
        // Add spinner and remove existing content
        $target.append($("<div/>", { class: "js-orcid-progress", text: "Requesting Profile" }))
      },
      success: function(data, _status, _xhr) {
        $target.append(data)
      },
      error: function(_xhr, status, _error) {
        console.log("Error:", status)
      },
      complete: function(_xhr, _status){
         $(".js-orcid-progress").remove()
      }
    });
  }

  $("body").attr("data-js-loaded", "true")
}

// Ensure that page load (via turbolinks) and page refresh (via browser request) both load JS
$(document).ready(onLoad)
$(document).on("turbolinks:load", onLoad)
