package com.uterspace.model;

import java.io.Serializable;
import java.util.Objects;

public class GroupMemberId implements Serializable {
    private int group;
    private int user;

    public GroupMemberId() {}

    public GroupMemberId(int group, int user) {
        this.group = group;
        this.user = user;
    }

    public int getGroup() { return group; }
    public void setGroup(int group) { this.group = group; }

    public int getUser() { return user; }
    public void setUser(int user) { this.user = user; }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        GroupMemberId that = (GroupMemberId) o;
        return group == that.group && user == that.user;
    }

    @Override
    public int hashCode() {
        return Objects.hash(group, user);
    }
}
