SHELL := cmd.exe
.SHELLFLAGS := /C

VIVADO ?= vivado
TEST ?= axis_buff_random
WORKSPACE ?= workspace

TESTS := axis_buff_random conv_gauss_random conv_sobel_random sig_xy_random

.PHONY: help list test test-all clean clean-all $(TESTS)

help:
	@echo Available targets:
	@echo   make list
	@echo   make test TEST=axis_buff_random
	@echo   make test-all
	@echo   make clean TEST=axis_buff_random
	@echo   make clean-all
	@echo.
	@echo Variables:
	@echo   TEST=$(TEST)
	@echo   VIVADO=$(VIVADO)
	@echo   WORKSPACE=$(WORKSPACE)

list:
	@echo $(TESTS)

test:
	@if not exist "$(WORKSPACE)" mkdir "$(WORKSPACE)"
	@if not exist "tests\$(TEST)\run_sim.tcl" (echo Unknown or missing test: $(TEST) && exit /b 2)
	@echo Running $(TEST)...
	@cd /d "$(WORKSPACE)" && $(VIVADO) -mode batch -source "..\tests\$(TEST)\run_sim.tcl"

$(TESTS):
	@$(MAKE) test TEST=$@

test-all:
	@$(MAKE) test TEST=axis_buff_random
	@$(MAKE) test TEST=conv_gauss_random
	@$(MAKE) test TEST=conv_sobel_random
	@$(MAKE) test TEST=sig_xy_random

clean:
	@if exist "$(WORKSPACE)\$(TEST)" rmdir /s /q "$(WORKSPACE)\$(TEST)"
	@if exist "$(WORKSPACE)\vivado.log" del /q "$(WORKSPACE)\vivado.log"
	@if exist "$(WORKSPACE)\vivado.jou" del /q "$(WORKSPACE)\vivado.jou"
	@if exist "$(WORKSPACE)\vivado_*.backup.log" del /q "$(WORKSPACE)\vivado_*.backup.log"
	@if exist "$(WORKSPACE)\vivado_*.backup.jou" del /q "$(WORKSPACE)\vivado_*.backup.jou"

clean-all:
	@if exist "$(WORKSPACE)" rmdir /s /q "$(WORKSPACE)"
