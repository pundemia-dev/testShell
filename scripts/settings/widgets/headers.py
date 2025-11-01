import customtkinter as ctk


class H1(ctk.CTkLabel):
    def __init__(self, master, text):
        super().__init__(master, text=text, font=("Dank Mono", 25), padx=50, pady=5, anchor="w")
        self.padX = 50
        self.padY = 5


class H2(ctk.CTkLabel):
    def __init__(self, master, text):
        super().__init__(master, text=text, font=("Dank Mono", 20), padx=25, pady=4, anchor="w")
        self.padX = 25
        self.padY = 4
