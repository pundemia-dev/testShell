import customtkinter
from typing import Callable, Union
from widgets.colors import colors


def my_constrain(value, lower_order, upper_order):
    value = value if value >= lower_order else lower_order 
    value = value if value <= upper_order else upper_order
    return value

def my_count_decimals(value):
    s = format(value, 'f')          
    s = s.rstrip('0').rstrip('.') 
    if '.' in s:
        return len(s.split('.')[1])
    else:
        return 0

def my_round(value, step_size):
    return round(value, my_count_decimals(step_size))

class Spinbox(customtkinter.CTkFrame):
    def __init__(self, *args,
                 width: int = 60,
                 height: int = 30,
                 step_size: int = 1,
                 command: Callable = None,
                 **kwargs):
        super().__init__(*args, **kwargs)

        self.step_size = step_size
        self.lower_order = 0
        self.upper_order = 15
        self.command = command

        self.surface_color = colors.surfaceContainer
        self.primary_color = colors.secondary
        self.surface_variant = colors.inverseOnSurface
        self.on_surface = colors.onSurface
        self.border_color = colors.outline
        self.corner_radius = 6
        self.border_width = 1
        self.button_paddings = 4
        self.button_text_size = 22
        # self.divider_color = colors.secondaryContainer
        # self.button_text_color = colors.secondaryContainer
        

        self.configure(fg_color=self.surface_color, border_color=self.border_color, border_width=self.border_width)  # set frame color

        self.grid_columnconfigure((0, 2), weight=0)  # buttons don't expand
        self.grid_columnconfigure(1, weight=1)  # entry expands

        # self.subtract_button = customtkinter.CTkButton(self, text="\ueaf2", font=("tabler-icons", 10), width=height, height=height, text_color=self.first_color, fg_color=self.second_color, corner_radius=height/2,
        self.subtract_button = customtkinter.CTkButton(self, text="-", font=("Dank Mono", self.button_text_size), width=height-(self.button_paddings*2), height=height-(self.button_paddings*2), text_color=self.primary_color, fg_color=self.surface_color, corner_radius=self.corner_radius, hover_color=self.surface_variant,
                                                       command=self.subtract_button_callback)
        self.subtract_button.grid(row=0, column=0, padx=(self.button_paddings, 0), pady=self.button_paddings)
        # self.divider1 = customtkinter.CTkFrame(self, width=3, height=height-4, fg_color=self.divider_color, corner_radius=1)
        # self.divider1.grid(row=0,column=1,padx=0, pady=2, sticky="nsew")

        self.entry = customtkinter.CTkEntry(self, width=width, height=height, border_width=0, fg_color=self.surface_color, text_color=self.on_surface, corner_radius=self.corner_radius, justify="right")
        self.entry.grid(row=0, column=1, columnspan=1, padx=5, pady=self.border_width, sticky="ew")
        self.entry.bind("<Leave>", self.focus_leave)
        self.entry.bind("<FocusOut>", self.focus_leave)
        self.entry.bind("<Button-4>", lambda event: self.subtract_button_callback())
        self.entry.bind("<Button-5>", lambda event: self.add_button_callback())
        # self.entry.bind("<FocusOut>", self.focus_leave)

        # self.divider2 = customtkinter.CTkFrame(self, width=3, height=height-4, fg_color=self.divider_color, corner_radius=1)
        # self.divider2.grid(row=0,column=3,padx=0, pady=2, sticky="nsew")
        # self.add_button = customtkinter.CTkButton(self, text="\ueb0b", font=("tabler-icons", 10), width=height, height=height, text_color=self.first_color, fg_color=self.second_color, corner_radius=height/2, border_spacing=0,
        self.add_button = customtkinter.CTkButton(self, text="+", font=("Dank Mono", self.button_text_size), width=height-(self.button_paddings * 2), height=height-(self.button_paddings*2), text_color=self.primary_color, fg_color=self.surface_color, corner_radius=self.corner_radius, border_spacing=0, hover_color=self.surface_variant,
                                                  command=self.add_button_callback)
        self.add_button.grid(row=0, column=2, padx=(0, self.button_paddings), pady=self.button_paddings)

        # default value
        self.entry.insert(0, "0.0")

    def focus_leave(self, event=None):
        if self.command is not None:
            self.command()
        try:
            value = my_constrain(int(float((self.entry.get()))), self.lower_order, self.upper_order)
            self.entry.delete(0, "end")
            self.entry.insert(0, value)
        except ValueError:
            return

    def add_button_callback(self):
        if self.command is not None:
            self.command()
        try:
            value = my_constrain(int(float(self.entry.get())) + self.step_size, self.lower_order, self.upper_order)
            self.entry.delete(0, "end")
            self.entry.insert(0, value)
        except ValueError:
            return

    def subtract_button_callback(self):
        if self.command is not None:
            self.command()
        try:
            value = my_constrain(int(float(self.entry.get())) - self.step_size, self.lower_order, self.upper_order)
            self.entry.delete(0, "end")
            self.entry.insert(0, value)
        except ValueError:
            return

    def get(self) -> Union[int, None]:
        try:
            return int(float(self.entry.get()))
        except ValueError:
            return None

    def set(self, value: int):
        self.entry.delete(0, "end")
        self.entry.insert(0, str(int(value)))
        
