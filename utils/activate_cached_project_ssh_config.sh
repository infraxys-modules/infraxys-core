	
	log_info "Restoring SSH configuration from the project cache";
    
    mkdir -p ~/.ssh/keys/;
	mkdir -p ~/.ssh/generated.d/;
	
	cp  /cache/project/.ssh/keys/* ~/.ssh/keys/;
	cp /cache/project/.ssh/config.d/* ~/.ssh/generated.d;
