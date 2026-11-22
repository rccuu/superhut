$(function () {
    //使用中旋转图标
    var round = 0;
    setInterval(function () {
        working();
    }, 1000);

    function working() {
        round++;
        var rdeg = round * 360;
        $(".working").css("transform", "rotate(" + rdeg + "deg)");
    }

    $(".tosl").click(function () {
        allbathroomcode = $(this).attr("bcode");//确认预约携带浴室编号
        //预约日期
        allodate = $(this).parent().parent().find("input[name='orderdate']").val();
        //预约开始时间
        allobtime = $(this).parent().parent().find("input[name='orderbegintime']").val();
        //预约结束
        alloetime = $(this).parent().parent().find("input[name='orderendtime']").val();
        //预约类型
        alltype = $(this).parent().parent().find("select[name='verficationtype']").val();
        $(".a-sl-page").fadeIn("fast");
    });

    //点击取消隐藏确认弹窗
    $(".b-btn").click(function () {
        $(this).parents(".alert-page").css("display", "none");
    });
});

/**热水结束使用**/
function endUse() {
    $(".a-sl-page").hide();
    $(".a-s-page").show();
    var openid = $("#openid").val();
    var poscodestr = $("#poscodestr").text();
    var openappid = $("#openappid").val();
    var poscode = poscodestr.substring(poscodestr.indexOf(":") + 1, poscodestr.length);

    dkyw.request.post("/boiling/endUse", {
        "openid": openid,
        "poscode": poscode,
        "openappid":openappid
    }, function (response) {
        if (response.success) {
            var data = response.resultData;
            if ("000000" == data.result) {
                $("#closesuc").show();
            } else {
                $("#closefail").show();
                $("#closefailmsg").html(queryI18n("water.closefailmsg") + queryI18n(data.result));
            }
        } else {
            $("#closefail").show();
        }
    });
}