//package drimer.drimain.controller;
//
//import jakarta.servlet.http.HttpServletRequest;
//import org.springframework.boot.web.servlet.error.ErrorController;
//import org.springframework.stereotype.Controller;
//import org.springframework.ui.Model;
//import org.springframework.web.bind.annotation.RequestMapping;
//
//@Controller
//public class AppErrorController implements ErrorController {
//
//    @RequestMapping("/error")
//    public String handleError(HttpServletRequest request, Model model) {
//        Object status = request.getAttribute("jakarta.servlet.error.status_code");
//        model.addAttribute("status", status);
//        return "access-denied"; // lub przygotuj osobny error.html
//    }
//}