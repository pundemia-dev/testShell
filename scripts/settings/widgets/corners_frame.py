import customtkinter as ctk
import math


class CornersFrame(ctk.CTkFrame):
    def __init__(self, master, fg_color, left_corner_radius, right_corner_radius, cursor_manipulation=False, **kwargs):
        super().__init__(master, fg_color="transparent", **kwargs)
        # self.configure(fg_color="red")
        # left_corner_radius = 20000
        # right_corner_radius = 10
        # self.width = width
        # self.height = height
        self.width = None
        self.height = None 
        self.fg_color = fg_color
        self.left_corner_radius = left_corner_radius
        self.right_corner_radius = right_corner_radius

        self.leftFrame = ctk.CTkFrame(self, fg_color=self.fg_color, corner_radius=left_corner_radius, border_width=0, border_color=self.fg_color)
        self.centerFrame = ctk.CTkFrame(self, fg_color=self.fg_color, corner_radius=0,border_width=-1, border_color=self.fg_color)#bg_color=self.fg_color)
        self.rightFrame = ctk.CTkFrame(self, fg_color=self.fg_color, corner_radius=right_corner_radius, border_width=0, border_color=self.fg_color)
        if cursor_manipulation:
            self.leftFrame.configure(cursor="hand2")
            self.rightFrame.configure(cursor="hand2")
            self.centerFrame.configure(cursor="hand2")
        # self.centerFrame._canvas.configure(bg="yellow", width=self.centerFrame._current_width-1)
        # print(self.centerFrame._canvas.winfo_width(), self.centerFrame._current_width)
        super().bind("<Configure>", lambda event: self.redraw(event))

        # self.redraw()

    def redraw(self, event=None):
        if event:
            self.width = event.width
            self.height = event.height
        self.leftFrame.place_forget()
        self.rightFrame.place_forget()
        self.centerFrame.place_forget()

        # print(f"{self.centerFrame._current_height=} {self.centerFrame._canvas.winfo_height()=} {height=}")
        self.centerFrame.configure(height=self.height-1, width=min(self.left_corner_radius, self.right_corner_radius))
        self.leftFrame.place(relx=0, rely=0, relwidth=0.5 if self.left_corner_radius < self.right_corner_radius else 1, relheight=1)
        self.rightFrame.place(relx=0 if self.left_corner_radius < self.right_corner_radius else 0.5, rely=0, relwidth=1 if self.left_corner_radius < self.right_corner_radius else 0.5, relheight=1)
        self.centerFrame.place(relx=0.5+(0 if self.left_corner_radius > self.right_corner_radius else 1)*(1 if self.left_corner_radius >= self.right_corner_radius else -1)*((min(self.left_corner_radius, self.right_corner_radius)/(self.width))), rely=0)#, relwidth=(min(self.left_corner_radius, self.right_corner_radius)/(width)), relheight=1)#relheight=(self.centerFrame._current_height/height))
        if self.left_corner_radius <= self.right_corner_radius:
            self.leftFrame.lift()
        else:
            self.rightFrame.lift()
        if min(self.left_corner_radius, self.right_corner_radius) < self.width/2:
            self.centerFrame.lift()

    def change_radius(self, left_corner_radius=None, right_corner_radius=None):
        flag = False

        if left_corner_radius:
            flag = True
            self.left_corner_radius = left_corner_radius
            self.leftFrame.configure(corner_radius=self.left_corner_radius)
        if right_corner_radius:
            flag = True
            self.right_corner_radius = right_corner_radius
            self.rightFrame.configure(corner_radius=self.right_corner_radius)

        if flag:
            self.redraw()

    def change_color(self, color):
        self.leftFrame.configure(fg_color=color)
        self.centerFrame.configure(fg_color=color)
        self.rightFrame.configure(fg_color=color)

    def bind(self, event, func):
        super().bind(event, func)
        self.leftFrame.bind(event, func)
        self.rightFrame.bind(event, func)
        self.centerFrame.bind(event, func)
        
