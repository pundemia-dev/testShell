import customtkinter as ctk
from widgets.colors import colors
from widgets.corners_frame import CornersFrame
from customtkinter.windows.widgets.core_widget_classes import DropdownMenu

class OptionMenu(ctk.CTkFrame):
    def __init__(self, master, values, icons, default):
        # self.width = width
        self.height = 35
        super().__init__(master, height=self.height, fg_color="transparent")
        self.fg_color = colors.secondaryContainer
        self.text_color = colors.onSecondaryContainer
        self.dropdown_fg_color = colors.secondary
        self.dropdown_text_color = colors.onSecondary
        self.drowpdown_selected_fg_color = colors.tertiaryContainer
        self.dropdown_selected_text_color = colors.onTertiaryContainer
        self.dropdown_hover_color = colors.tertiaryContainer
        self.selected = default
        self._values = values
        self.icons = icons
        self.minRadius = 5
        self.maxRadius = self.height / 2
        self.padX = 0
        self.label_left_padx = self.maxRadius
        self.label_right_padx = self.maxRadius
        self.label_center_padx = 3

        self.labelFrame = ctk.CTkFrame(self, fg_color="transparent", height=self.height)#"transparent")
        self.buttonFrame = ctk.CTkFrame(self, fg_color="transparent", width=self.height, height=self.height)#"transparent")
        self.labelFrame.grid(row=0, column=0, padx=(0, self.padX), pady=0, sticky="nsew")
        self.buttonFrame.grid(row=0, column=1, padx=0, pady=0, sticky="nsew")

        self.label = ctk.CTkLabel(self.labelFrame, fg_color=self.fg_color, text_color=self.text_color, text=self._values[self.selected], font=("Dank Mono", 14), padx=0, pady=0, corner_radius=0, bg_color=self.fg_color)
        self.button = ctk.CTkLabel(self.buttonFrame, fg_color=self.fg_color, text_color=self.text_color, text="\uea5f", font=("tabler-icons", 15), padx=0, pady=0, corner_radius=0, bg_color=self.fg_color)
        self.label.bind("<Configure>", self._on_resize_label)
        self.labelCornersFrame = CornersFrame(self.labelFrame, height=self.height, width=self.label.winfo_width()+self.label_left_padx+self.label_right_padx,fg_color=self.fg_color, left_corner_radius=self.maxRadius, right_corner_radius=self.minRadius)
        self.buttonCornersFrame = CornersFrame(self.buttonFrame, height=self.height, width=self.height, fg_color=self.fg_color, left_corner_radius=self.minRadius, right_corner_radius=self.maxRadius, cursor_manipulation=True)
        self.label.grid(row=0,column=1, padx=(0, self.maxRadius), pady=0)
        self.button.grid(row=0,column=1, padx=0, pady=0)
        self.icon = ctk.CTkLabel(self.labelFrame, text=self.icons[self.selected], font=("tabler-icons", 20), fg_color=self.fg_color, text_color=self.text_color)
        self.icon.grid(row=0, column=0, padx=(self.maxRadius, self.label_center_padx), pady=0)
        self.labelCornersFrame.grid(row=0, column=0, columnspan=2)
        self.buttonCornersFrame.grid(row=0, column=1)
        self.icon.lift()
        self.icon.lift()
        self.label.lift()
        self.label.lift()

        self.button.lift()
        self.button.lift()
        self.button.bind("<Button>", self._button_callback)
        self.buttonFrame.bind("<Button>", self._button_callback)
        self.buttonCornersFrame.bind("<Button>", self._button_callback)
        self.button.configure(cursor="hand2")

        self._dropdown_menu = DropdownMenu(master=self,
                                           values=self._values,
                                           command=self._dropdown_callback,
                                           fg_color=self.dropdown_fg_color,
                                           hover_color=self.dropdown_hover_color,
                                           text_color=self.dropdown_text_color,
                                           font=("Dank Mono", 15))
        self._dropdown_menu.bind("<FocusOut>", lambda _: self._on_close_dropdown())

    def _on_resize_label(self, event):
        self.labelCornersFrame.configure(width=event.width+self.label_left_padx+self.label_right_padx+self.icon.winfo_width()+self.label_center_padx)
        self.labelFrame.configure(width=event.width+self.label_left_padx+self.label_right_padx+self.icon.winfo_width()+self.label_center_padx)
        # print(event.width, event.height)

    def _button_callback(self, _):
        self.buttonCornersFrame.change_radius(left_corner_radius=self.maxRadius, right_corner_radius=self.maxRadius)
        self.button.configure(text="\uea62")
        self._dropdown_menu.open(self.winfo_rootx(),
                                 self.winfo_rooty() + self._current_height + 0)

    def _dropdown_callback(self, event):
        print(event)
        self.selected = self._values.index(event)
        self.label.configure(text=event)
        self.icon.configure(text=self.icons[self.selected])
        self._on_close_dropdown()

    def _on_close_dropdown(self):
        self.buttonCornersFrame.change_radius(left_corner_radius=self.minRadius, right_corner_radius=self.maxRadius)
        self.button.configure(text="\uea5f")
